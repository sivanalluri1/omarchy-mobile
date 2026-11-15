/* Read-only DRM/KGSL enumeration. No modeset, allocation or submission. */
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#define __user
#include "msm_kgsl.h"

int main(void)
{
    int failures = 0;
    int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("DRM open"); failures++; }
    else {
        drmVersionPtr v = drmGetVersion(fd);
        if (v) {
            printf("DRM driver=%.*s version=%d.%d.%d\n", v->name_len, v->name,
                   v->version_major, v->version_minor, v->version_patchlevel);
            drmFreeVersion(v);
        } else { perror("DRM version"); failures++; }
        uint64_t value;
        if (!drmGetCap(fd, DRM_CAP_DUMB_BUFFER, &value))
            printf("DRM dumb_buffer=%" PRIu64 "\n", value);
        if (!drmGetCap(fd, DRM_CAP_PRIME, &value))
            printf("DRM prime_caps=%" PRIu64 "\n", value);
        drmModeResPtr r = drmModeGetResources(fd);
        if (!r) { perror("DRM resources"); failures++; }
        else {
            printf("DRM connectors=%d crtcs=%d encoders=%d max=%ux%u\n",
                   r->count_connectors, r->count_crtcs, r->count_encoders,
                   r->max_width, r->max_height);
            for (int i = 0; i < r->count_connectors; i++) {
                drmModeConnectorPtr c = drmModeGetConnector(fd, r->connectors[i]);
                if (!c) { perror("DRM connector"); failures++; continue; }
                printf("connector=%u type=%u status=%u encoder=%u modes=%d\n",
                       c->connector_id, c->connector_type, c->connection,
                       c->encoder_id, c->count_modes);
                for (int j = 0; j < c->count_modes; j++) {
                    drmModeModeInfo *m = &c->modes[j];
                    printf(" mode=%s %ux%u refresh=%u clock=%u flags=%#x type=%#x\n",
                           m->name, m->hdisplay, m->vdisplay, m->vrefresh,
                           m->clock, m->flags, m->type);
                }
                drmModeFreeConnector(c);
            }
            for (int i = 0; i < r->count_encoders; i++) {
                drmModeEncoderPtr e = drmModeGetEncoder(fd, r->encoders[i]);
                if (!e) continue;
                printf("encoder=%u crtc=%u possible_crtcs=%#x\n",
                       e->encoder_id, e->crtc_id, e->possible_crtcs);
                drmModeFreeEncoder(e);
            }
            for (int i = 0; i < r->count_crtcs; i++) {
                drmModeCrtcPtr c = drmModeGetCrtc(fd, r->crtcs[i]);
                if (!c) continue;
                printf("crtc=%u fb=%u valid=%d mode=%s\n", c->crtc_id,
                       c->buffer_id, c->mode_valid, c->mode_valid ? c->mode.name : "none");
                drmModeFreeCrtc(c);
            }
            drmModeFreeResources(r);
        }
        if (drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1))
            perror("universal planes capability");
        drmModePlaneResPtr planes = drmModeGetPlaneResources(fd);
        if (planes) {
            for (uint32_t i=0; i<planes->count_planes; i++) {
                drmModePlanePtr plane = drmModeGetPlane(fd, planes->planes[i]);
                if (!plane) continue;
                unsigned duplicates = 0;
                for (uint32_t j=0; j<plane->count_formats; j++)
                    for (uint32_t k=0; k<j; k++)
                        if (plane->formats[j] == plane->formats[k]) {
                            printf("plane=%u duplicate_format=%#x at=%u earlier=%u\n",
                                   plane->plane_id, plane->formats[j], j, k);
                            duplicates++; break;
                        }
                printf("plane=%u formats=%u duplicates=%u possible_crtcs=%#x\n",
                       plane->plane_id, plane->count_formats, duplicates, plane->possible_crtcs);
                drmModeFreePlane(plane);
            }
            drmModeFreePlaneResources(planes);
        }
        close(fd);
    }
    fd = open("/dev/kgsl-3d0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("KGSL open"); failures++; }
    else {
        struct kgsl_devinfo info = {0};
        struct kgsl_device_getproperty prop = {
            .type = KGSL_PROP_DEVICE_INFO, .value = &info, .sizebytes = sizeof(info)
        };
        if (ioctl(fd, IOCTL_KGSL_DEVICE_GETPROPERTY, &prop)) {
            perror("KGSL device info"); failures++;
        } else printf("KGSL device=%u chip=%#x gpu_id=%u mmu=%u gmem_bytes=%zu\n",
                      info.device_id, info.chip_id, info.gpu_id,
                      info.mmu_enabled, info.gmem_sizebytes);
        close(fd);
    }
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
