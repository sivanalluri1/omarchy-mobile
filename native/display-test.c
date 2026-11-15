/* Bounded CPU-rendered KMS test. No GPU acceleration claim. */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm_fourcc.h>
static volatile sig_atomic_t stop;
static void interrupted(int sig) { (void)sig; stop = 1; }
int main(int argc, char **argv)
{
    if (argc != 2 || strcmp(argv[1], "--show-120-seconds")) {
        fprintf(stderr,"Usage: display-test --show-120-seconds\n"); return 2;
    }
    setbuf(stdout,NULL);
    int fd = open("/dev/dri/card0",O_RDWR|O_CLOEXEC), result = 1;
    if (fd < 0) { perror("open"); return 1; }
    drmModeResPtr r = drmModeGetResources(fd);
    drmModeConnectorPtr c = NULL;
    drmModeCrtcPtr previous = NULL;
    uint32_t crtc = 0, fb = 0;
    int displayed = 0;
    void *map = MAP_FAILED;
    struct drm_mode_create_dumb b = {0};
    if (!r) { perror("resources"); goto done; }
    for (int i=0;i<r->count_connectors;i++) {
        drmModeConnectorPtr candidate=drmModeGetConnector(fd,r->connectors[i]);
        if (candidate && candidate->connector_type==DRM_MODE_CONNECTOR_DSI &&
            candidate->connection==DRM_MODE_CONNECTED && candidate->count_modes) {
            c=candidate; break;
        }
        if (candidate) drmModeFreeConnector(candidate);
    }
    if (!c) { fprintf(stderr,"No connected DSI panel\n"); goto done; }
    for (int i=0;i<c->count_encoders && !crtc;i++) {
        drmModeEncoderPtr e=drmModeGetEncoder(fd,c->encoders[i]);
        if (!e) continue;
        for (int j=0;j<r->count_crtcs;j++)
            if (e->possible_crtcs & (1u<<j)) { crtc=r->crtcs[j]; break; }
        drmModeFreeEncoder(e);
    }
    if (!crtc) { fprintf(stderr,"No compatible CRTC\n"); goto done; }
    previous=drmModeGetCrtc(fd,crtc);
    if (!previous) { perror("save CRTC"); goto done; }
    b.width=c->modes[0].hdisplay; b.height=c->modes[0].vdisplay; b.bpp=32;
    if (drmIoctl(fd,DRM_IOCTL_MODE_CREATE_DUMB,&b)) { perror("create dumb"); goto done; }
    uint32_t handles[4]={b.handle}, pitches[4]={b.pitch}, offsets[4]={0};
    if (drmModeAddFB2(fd,b.width,b.height,DRM_FORMAT_XRGB8888,handles,pitches,offsets,&fb,0)) {
        perror("add framebuffer"); goto done;
    }
    struct drm_mode_map_dumb m = {.handle=b.handle};
    if (drmIoctl(fd,DRM_IOCTL_MODE_MAP_DUMB,&m)) { perror("map dumb"); goto done; }
    map=mmap(NULL,b.size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,m.offset);
    if (map==MAP_FAILED) { perror("mmap"); goto done; }
    const uint32_t colors[]={0xffffff,0xffff00,0x00ffff,0x00ff00,0xff00ff,0xff0000,0x0000ff,0x303030};
    for(uint32_t y=0;y<b.height;y++) {
        uint32_t *row=(uint32_t *)((char *)map+(size_t)y*b.pitch);
        for(uint32_t x=0;x<b.width;x++) row[x]=colors[(uint64_t)x*8/b.width];
    }
    signal(SIGINT,interrupted); signal(SIGTERM,interrupted);
    if (drmModeSetCrtc(fd,crtc,fb,0,0,&c->connector_id,1,&c->modes[0])) {
        perror("set CRTC"); goto done;
    }
    displayed=1;
    printf("DISPLAY_ACTIVE connector=%u crtc=%u mode=%s framebuffer=%u duration=120s\n",
           c->connector_id,crtc,c->modes[0].name,fb);
    for(int i=0;i<120 && !stop;i++) sleep(1);
    result=0;
done:
    if(displayed) {
        int ret;
        if(previous->buffer_id && previous->mode_valid)
            ret=drmModeSetCrtc(fd,crtc,previous->buffer_id,previous->x,previous->y,
                               &c->connector_id,1,&previous->mode);
        else ret=drmModeSetCrtc(fd,crtc,0,0,0,NULL,0,NULL);
        if(ret) { perror("restore/disable CRTC"); result=1; }
    }
    if(map!=MAP_FAILED) munmap(map,b.size);
    if(fb && drmModeRmFB(fd,fb)) { perror("remove framebuffer"); result=1; }
    if(b.handle) { struct drm_mode_destroy_dumb d={.handle=b.handle};
        if(drmIoctl(fd,DRM_IOCTL_MODE_DESTROY_DUMB,&d)) {perror("destroy dumb"); result=1;} }
    if(previous) drmModeFreeCrtc(previous);
    if(c) drmModeFreeConnector(c);
    if(r) drmModeFreeResources(r);
    close(fd);
    return result;
}
