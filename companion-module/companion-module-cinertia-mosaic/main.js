// Bitfocus Companion module for the Cinertia Mosaic NDI multiviewer.
//
// Talks Mosaic's line-based TCP protocol (default port 9955):
//   commands:  PROFILE <name> · PROFILEINDEX <n> · LAYOUT <id> ·
//              MODE <windowed|fullscreen|windowless> · PING ·
//              PROFILES? · STATUS?
//   pushes:    EVENT PROFILE <name> · EVENT PROFILES <json> ·
//              EVENT MODE <mode>
// Enable the server in Mosaic: Settings -> Enable TCP remote control.

const {
    InstanceBase,
    InstanceStatus,
    TCPHelper,
    runEntrypoint,
    combineRgb,
} = require('@companion-module/base')

const LAYOUTS = [
    { id: '2x2', label: '2×2 grid' },
    { id: '3x3', label: '3×3 grid' },
    { id: '4x4', label: '4×4 grid' },
    { id: '1+side', label: '1 large + side column' },
    { id: '2+8', label: '2 large + rows of 4' },
]

const MODES = [
    { id: 'windowed', label: 'Windowed' },
    { id: 'fullscreen', label: 'Fullscreen' },
    { id: 'windowless', label: 'Windowless' },
]

class MosaicInstance extends InstanceBase {
    async init(config) {
        this.config = config
        this.profiles = []
        this.currentProfile = ''
        this.displayMode = ''
        this.tileCount = 0
        this.rxBuffer = ''
        this.connected = false
        this.lastRx = 0

        this.setupActions()
        this.setupFeedbacks()
        this.setupVariables()
        this.setupPresets()
        this.initConnection()
    }

    async destroy() {
        if (this.heartbeat) {
            clearInterval(this.heartbeat)
            delete this.heartbeat
        }
        if (this.socket) {
            this.socket.destroy()
            delete this.socket
        }
    }

    async configUpdated(config) {
        this.config = config
        this.initConnection()
    }

    getConfigFields() {
        return [
            {
                type: 'static-text',
                id: 'info',
                width: 12,
                label: 'Setup',
                value: 'In Mosaic, open Settings (gear) and turn on "Enable TCP remote control". Enter that PC\'s IP and port here.',
            },
            {
                type: 'textinput',
                id: 'host',
                label: 'Mosaic IP address',
                width: 8,
                default: '127.0.0.1',
            },
            {
                type: 'number',
                id: 'port',
                label: 'Port',
                width: 4,
                default: 9955,
                min: 1,
                max: 65535,
            },
        ]
    }

    // ------------------------------------------------------- connection
    setConnected(ok) {
        if (ok === this.connected) return
        this.connected = ok
        this.setVariableValues({ connection: ok ? 'ok' : 'lost' })
        this.checkFeedbacks('connection_lost')
    }

    initConnection() {
        if (this.heartbeat) {
            clearInterval(this.heartbeat)
            delete this.heartbeat
        }
        if (this.socket) {
            this.socket.destroy()
            delete this.socket
        }
        this.setConnected(false)
        if (!this.config.host) {
            this.updateStatus(InstanceStatus.BadConfig, 'No host set')
            return
        }

        this.updateStatus(InstanceStatus.Connecting)
        this.socket = new TCPHelper(this.config.host, this.config.port || 9955)

        this.socket.on('connect', () => {
            this.updateStatus(InstanceStatus.Ok)
            this.rxBuffer = ''
            this.lastRx = Date.now()
            this.setConnected(true)
            this.send('PROFILES?')
            this.send('STATUS?')
        })

        this.socket.on('data', (chunk) => {
            this.lastRx = Date.now()
            this.rxBuffer += chunk.toString('utf8')
            let idx
            while ((idx = this.rxBuffer.indexOf('\n')) >= 0) {
                const line = this.rxBuffer.slice(0, idx).trim()
                this.rxBuffer = this.rxBuffer.slice(idx + 1)
                if (line.length > 0) this.handleLine(line)
            }
        })

        this.socket.on('error', (err) => {
            this.setConnected(false)
            this.updateStatus(InstanceStatus.ConnectionFailure, String(err))
        })

        this.socket.on('status_change', (status) => {
            if (status !== 'connected') this.setConnected(false)
        })

        // Heartbeat: PING every 5s; if nothing (not even an OK) has come
        // back for 12s the link is considered dead — the feedback goes
        // red and the connection is rebuilt automatically.
        this.heartbeat = setInterval(() => {
            if (this.socket && this.socket.isConnected) {
                if (Date.now() - this.lastRx > 12000) {
                    this.setConnected(false)
                    this.updateStatus(
                        InstanceStatus.ConnectionFailure,
                        'Mosaic stopped responding'
                    )
                    this.initConnection()
                    return
                }
                this.send('PING')
            } else {
                this.setConnected(false)
            }
        }, 5000)
    }

    send(line) {
        if (this.socket && this.socket.isConnected) {
            this.socket.send(line + '\n')
        }
    }

    // --------------------------------------------------------- protocol
    handleLine(line) {
        const space = line.indexOf(' ')
        const keyword = (space < 0 ? line : line.slice(0, space)).toUpperCase()
        const rest = space < 0 ? '' : line.slice(space + 1).trim()

        if (keyword === 'PROFILES') {
            this.setProfiles(rest)
        } else if (keyword === 'STATUS') {
            try {
                const st = JSON.parse(rest)
                this.currentProfile = st.profile || ''
                this.displayMode = st.mode || ''
                this.tileCount = st.tiles || 0
                this.pushState()
            } catch (e) {
                this.log('warn', `Bad STATUS payload: ${rest}`)
            }
        } else if (keyword === 'EVENT') {
            const space2 = rest.indexOf(' ')
            const what = (space2 < 0 ? rest : rest.slice(0, space2)).toUpperCase()
            const value = space2 < 0 ? '' : rest.slice(space2 + 1).trim()
            if (what === 'PROFILE') {
                this.currentProfile = value
                this.pushState()
            } else if (what === 'PROFILES') {
                this.setProfiles(value)
            } else if (what === 'MODE') {
                this.displayMode = value
                this.pushState()
            }
        } else if (keyword === 'ERR') {
            this.log('warn', `Mosaic rejected a command: ${line}`)
        }
        // OK acknowledgements need no handling
    }

    setProfiles(json) {
        try {
            const list = JSON.parse(json)
            if (Array.isArray(list)) {
                this.profiles = list.map((p) => String(p))
                // Profile names feed dropdowns and presets — rebuild them.
                this.setupActions()
                this.setupFeedbacks()
                this.setupPresets()
                this.checkFeedbacks('active_profile')
            }
        } catch (e) {
            this.log('warn', `Bad PROFILES payload: ${json}`)
        }
    }

    pushState() {
        this.setVariableValues({
            current_profile: this.currentProfile,
            display_mode: this.displayMode,
            tile_count: this.tileCount,
        })
        this.checkFeedbacks('active_profile')
    }

    profileChoices() {
        if (this.profiles.length === 0) {
            return [{ id: '', label: '(no profiles saved in Mosaic yet)' }]
        }
        return this.profiles.map((p) => ({ id: p, label: p }))
    }

    // ---------------------------------------------------------- actions
    setupActions() {
        this.setActionDefinitions({
            profile: {
                name: 'Switch profile',
                options: [
                    {
                        type: 'dropdown',
                        id: 'profile',
                        label: 'Profile',
                        default: this.profiles[0] || '',
                        choices: this.profileChoices(),
                    },
                ],
                callback: (action) => {
                    if (action.options.profile)
                        this.send('PROFILE ' + action.options.profile)
                },
            },
            profile_index: {
                name: 'Switch profile by position',
                options: [
                    {
                        type: 'number',
                        id: 'index',
                        label: 'Position in list (1 = first)',
                        default: 1,
                        min: 1,
                        max: 99,
                    },
                ],
                callback: (action) => {
                    this.send('PROFILEINDEX ' + action.options.index)
                },
            },
            layout: {
                name: 'Apply layout',
                options: [
                    {
                        type: 'dropdown',
                        id: 'layout',
                        label: 'Layout',
                        default: '2x2',
                        choices: LAYOUTS,
                    },
                ],
                callback: (action) => {
                    this.send('LAYOUT ' + action.options.layout)
                },
            },
            mode: {
                name: 'Set display mode',
                options: [
                    {
                        type: 'dropdown',
                        id: 'mode',
                        label: 'Mode',
                        default: 'fullscreen',
                        choices: MODES,
                    },
                ],
                callback: (action) => {
                    this.send('MODE ' + action.options.mode)
                },
            },
            reconnect: {
                name: 'Reconnect to Mosaic',
                options: [],
                callback: () => this.initConnection(),
            },
        })
    }

    // -------------------------------------------------------- feedbacks
    setupFeedbacks() {
        this.setFeedbackDefinitions({
            connection_lost: {
                type: 'boolean',
                name: 'Connection to Mosaic lost',
                description: 'Change button style while Companion cannot reach Mosaic (checked with a 5s heartbeat). Pair with the Reconnect action on the same button.',
                defaultStyle: {
                    bgcolor: combineRgb(200, 40, 40),
                    color: combineRgb(255, 255, 255),
                },
                options: [],
                callback: () => !this.connected,
            },
            active_profile: {
                type: 'boolean',
                name: 'Profile is active',
                description: 'Change button style while the chosen profile is active in Mosaic',
                defaultStyle: {
                    bgcolor: combineRgb(61, 126, 255),
                    color: combineRgb(255, 255, 255),
                },
                options: [
                    {
                        type: 'dropdown',
                        id: 'profile',
                        label: 'Profile',
                        default: this.profiles[0] || '',
                        choices: this.profileChoices(),
                    },
                ],
                callback: (feedback) => {
                    return (
                        feedback.options.profile !== '' &&
                        feedback.options.profile === this.currentProfile
                    )
                },
            },
        })
    }

    // -------------------------------------------------------- variables
    setupVariables() {
        this.setVariableDefinitions([
            { variableId: 'current_profile', name: 'Active profile' },
            { variableId: 'display_mode', name: 'Display mode' },
            { variableId: 'tile_count', name: 'Tiles on canvas' },
            { variableId: 'connection', name: 'Connection state (ok / lost)' },
        ])
        this.setVariableValues({ connection: 'lost' })
    }

    // ---------------------------------------------------------- presets
    setupPresets() {
        const presets = {}
        presets['status'] = {
            type: 'button',
            category: 'Status',
            name: 'Mosaic connection (red when lost, press to reconnect)',
            style: {
                text: 'Mosaic\n$(mosaic:connection)',
                size: 'auto',
                color: combineRgb(64, 208, 96),
                bgcolor: combineRgb(20, 20, 23),
            },
            steps: [
                {
                    down: [{ actionId: 'reconnect', options: {} }],
                    up: [],
                },
            ],
            feedbacks: [
                {
                    feedbackId: 'connection_lost',
                    options: {},
                    style: {
                        bgcolor: combineRgb(200, 40, 40),
                        color: combineRgb(255, 255, 255),
                    },
                },
            ],
        }
        for (const p of this.profiles) {
            presets[`profile_${p}`] = {
                type: 'button',
                category: 'Profiles',
                name: `Switch to ${p}`,
                style: {
                    text: p,
                    size: 'auto',
                    color: combineRgb(216, 216, 220),
                    bgcolor: combineRgb(20, 20, 23),
                },
                steps: [
                    {
                        down: [{ actionId: 'profile', options: { profile: p } }],
                        up: [],
                    },
                ],
                feedbacks: [
                    {
                        feedbackId: 'active_profile',
                        options: { profile: p },
                        style: {
                            bgcolor: combineRgb(61, 126, 255),
                            color: combineRgb(255, 255, 255),
                        },
                    },
                ],
            }
        }
        for (const l of LAYOUTS) {
            presets[`layout_${l.id}`] = {
                type: 'button',
                category: 'Layouts',
                name: `Layout ${l.label}`,
                style: {
                    text: l.id,
                    size: 'auto',
                    color: combineRgb(216, 216, 220),
                    bgcolor: combineRgb(20, 20, 23),
                },
                steps: [
                    {
                        down: [{ actionId: 'layout', options: { layout: l.id } }],
                        up: [],
                    },
                ],
                feedbacks: [],
            }
        }
        this.setPresetDefinitions(presets)
    }
}

runEntrypoint(MosaicInstance, [])
