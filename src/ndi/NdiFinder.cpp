#include "NdiFinder.h"

#include <Processing.NDI.Lib.h>

NdiFinder::NdiFinder(QObject *parent)
    : QObject(parent)
{
    NDIlib_find_create_t desc;
    desc.show_local_sources = true;
    desc.p_groups = nullptr;
    desc.p_extra_ips = nullptr;
    m_finder = NDIlib_find_create_v2(&desc);

    connect(&m_timer, &QTimer::timeout, this, &NdiFinder::poll);
    m_timer.start(1000);
    poll();
}

NdiFinder::~NdiFinder()
{
    if (m_finder)
        NDIlib_find_destroy(static_cast<NDIlib_find_instance_t>(m_finder));
}

void NdiFinder::poll()
{
    if (!m_finder)
        return;

    uint32_t count = 0;
    const NDIlib_source_t *found = NDIlib_find_get_current_sources(
        static_cast<NDIlib_find_instance_t>(m_finder), &count);

    QStringList names;
    names.reserve(count);
    for (uint32_t i = 0; i < count; ++i)
        names.append(QString::fromUtf8(found[i].p_ndi_name));
    names.sort(Qt::CaseInsensitive);

    if (names != m_sources) {
        m_sources = names;
        emit sourcesChanged();
    }
}
