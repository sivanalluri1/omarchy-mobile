/* GPU/display sharing diagnostic; no KMS modeset or persistent storage. */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <gbm.h>
int main(void) {
    alarm(45);setbuf(stdout,NULL);
    int fd=open("/dev/dri/card0",O_RDWR|O_CLOEXEC);if(fd<0){perror("open");return 1;}
    struct gbm_device *g=gbm_create_device(fd);if(!g){perror("gbm create device");return 1;}
    printf("GBM backend=%s\n",gbm_device_get_backend_name(g));
    struct gbm_bo *b=gbm_bo_create(g,128,128,GBM_FORMAT_XRGB8888,GBM_BO_USE_RENDERING|GBM_BO_USE_SCANOUT);
    if(!b){perror("gbm bo create scanout");return 1;}
    int dmafd=gbm_bo_get_fd(b);printf("GBM bo dmafd=%d handle=%u stride=%u modifier=%#llx errno=%d\n",dmafd,gbm_bo_get_handle(b).u32,gbm_bo_get_stride(b),(unsigned long long)gbm_bo_get_modifier(b),errno);
    if(dmafd>=0)close(dmafd);
    gbm_bo_destroy(b);
    PFNEGLGETPLATFORMDISPLAYEXTPROC getdisplay=(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if(!getdisplay)return 1;
    EGLDisplay d=getdisplay(EGL_PLATFORM_GBM_KHR,g,NULL);EGLint major,minor;
    if(!eglInitialize(d,&major,&minor)){printf("EGL init error=%#x\n",eglGetError());return 1;}
    const EGLint attrs[]={EGL_SURFACE_TYPE,EGL_WINDOW_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,0,EGL_NONE};
    EGLConfig configs[64],config=NULL;EGLint count;
    if(!eglChooseConfig(d,attrs,configs,64,&count))return 1;
    for(int i=0;i<count;i++){EGLint visual;eglGetConfigAttrib(d,configs[i],EGL_NATIVE_VISUAL_ID,&visual);if(visual==GBM_FORMAT_XRGB8888){config=configs[i];break;}}
    if(!config){printf("No XRGB config\n");return 1;}
    struct gbm_surface *s=gbm_surface_create(g,128,128,GBM_FORMAT_XRGB8888,GBM_BO_USE_RENDERING|GBM_BO_USE_SCANOUT);
    if(!s){perror("gbm surface");return 1;}
    EGLSurface surface=eglCreateWindowSurface(d,config,(EGLNativeWindowType)s,NULL);
    if(surface==EGL_NO_SURFACE){printf("EGL window error=%#x\n",eglGetError());return 1;}
    eglBindAPI(EGL_OPENGL_ES_API);const EGLint ca[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    EGLContext c=eglCreateContext(d,config,EGL_NO_CONTEXT,ca);
    if(c==EGL_NO_CONTEXT || !eglMakeCurrent(d,surface,surface,c)){printf("EGL context error=%#x\n",eglGetError());return 1;}
    printf("GL renderer=%s\n",glGetString(GL_RENDERER));glClearColor(1,0,0,1);glClear(GL_COLOR_BUFFER_BIT);
    EGLBoolean swap=eglSwapBuffers(d,surface);printf("EGL swap=%u error=%#x glerror=%#x\n",swap,eglGetError(),glGetError());
    errno=0;b=gbm_surface_lock_front_buffer(s);int error=errno;
    if(!b){printf("GBM lock failed errno=%d EGL=%#x\n",error,eglGetError());return 1;}
    dmafd=gbm_bo_get_fd(b);
    uint32_t handle=gbm_bo_get_handle(b).u32;
    if(dmafd<0 || !handle || handle==UINT32_MAX) {fprintf(stderr,"Invalid scanout handle or DMA-BUF fd\n");return 1;}
    printf("GBM_SURFACE_PASS dmafd=%d handle=%u stride=%u modifier=%#llx\n",dmafd,gbm_bo_get_handle(b).u32,gbm_bo_get_stride(b),(unsigned long long)gbm_bo_get_modifier(b));
    if(dmafd>=0)close(dmafd);
    gbm_surface_release_buffer(s,b);
    eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);eglDestroyContext(d,c);eglDestroySurface(d,surface);eglTerminate(d);gbm_surface_destroy(s);gbm_device_destroy(g);close(fd);return 0;
}
