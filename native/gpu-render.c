/* Offscreen GLES2 triangle through Zink/Turnip, with exact colour readback. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
static void fail(const char *message) { fprintf(stderr,"%s EGL=%#x GL=%#x\n",message,eglGetError(),glGetError());exit(1); }
static GLuint shader(GLenum type,const char *text)
{
    GLuint s=glCreateShader(type);glShaderSource(s,1,&text,NULL);glCompileShader(s);
    GLint ok;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if(!ok) {char log[2048];glGetShaderInfoLog(s,sizeof(log),NULL,log);fprintf(stderr,"%s\n",log);fail("shader");}
    return s;
}
int main(void)
{
    alarm(60);setbuf(stdout,NULL);
    PFNEGLGETPLATFORMDISPLAYEXTPROC getdisplay=(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if(!getdisplay) fail("No platform display extension");
    EGLDisplay display=getdisplay(EGL_PLATFORM_SURFACELESS_MESA,EGL_DEFAULT_DISPLAY,NULL);
    EGLint major,minor;if(display==EGL_NO_DISPLAY || !eglInitialize(display,&major,&minor))fail("initialize");
    printf("EGL=%d.%d vendor=%s\n",major,minor,eglQueryString(display,EGL_VENDOR));
    if(!eglBindAPI(EGL_OPENGL_ES_API))fail("bind API");
    const EGLint attrs[]={EGL_SURFACE_TYPE,EGL_PBUFFER_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8,EGL_NONE};
    EGLConfig config; EGLint count;if(!eglChooseConfig(display,attrs,&config,1,&count)||count!=1)fail("config");
    const EGLint pbattrs[]={EGL_WIDTH,64,EGL_HEIGHT,64,EGL_NONE};
    EGLSurface surface=eglCreatePbufferSurface(display,config,pbattrs);if(surface==EGL_NO_SURFACE)fail("pbuffer");
    const EGLint ctxattrs[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    EGLContext context=eglCreateContext(display,config,EGL_NO_CONTEXT,ctxattrs);if(context==EGL_NO_CONTEXT)fail("context");
    if(!eglMakeCurrent(display,surface,surface,context))fail("make current");
    const char *renderer=(const char *)glGetString(GL_RENDERER);
    printf("GL_VENDOR=%s\nGL_RENDERER=%s\nGL_VERSION=%s\n",glGetString(GL_VENDOR),renderer,glGetString(GL_VERSION));
    if(!renderer || !strstr(renderer,"zink") || !strstr(renderer,"618") || strstr(renderer,"llvmpipe") || strstr(renderer,"softpipe"))fail("Refusing non-Adreno Zink renderer");
    GLuint vs=shader(GL_VERTEX_SHADER,"attribute vec2 position;void main(){gl_Position=vec4(position,0.,1.);}");
    GLuint fs=shader(GL_FRAGMENT_SHADER,"precision mediump float;void main(){gl_FragColor=vec4(1.,0.,0.,1.);}");
    GLuint program=glCreateProgram();glAttachShader(program,vs);glAttachShader(program,fs);glBindAttribLocation(program,0,"position");glLinkProgram(program);
    GLint linked;glGetProgramiv(program,GL_LINK_STATUS,&linked);if(!linked)fail("link");
    glUseProgram(program);glViewport(0,0,64,64);glDisable(GL_DITHER);
    glClearColor(0,0,1,1);glClear(GL_COLOR_BUFFER_BIT);
    const GLfloat vertices[]={-.75f,-.75f,.75f,-.75f,0,.75f};
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,vertices);glEnableVertexAttribArray(0);glDrawArrays(GL_TRIANGLES,0,3);
    unsigned char pixels[64*64*4];glReadPixels(0,0,64,64,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
    if(glGetError()!=GL_NO_ERROR)fail("draw/readback");
    unsigned red=0,blue=0;unsigned long long hash=14695981039346656037ull;
    for(unsigned i=0;i<64*64;i++) {
        unsigned char *p=pixels+i*4;
        if(p[0]==255 && p[1]==0 && p[2]==0 && p[3]==255)red++;
        if(p[0]==0 && p[1]==0 && p[2]==255 && p[3]==255)blue++;
        for(int j=0;j<4;j++) {hash^=p[j];hash*=1099511628211ull;}
    }
    unsigned char *center=pixels+(32*64+32)*4;
    if(red<1000 || red>1300 || red+blue!=4096 || center[0]!=255 || center[2]!=0 || pixels[0]!=0 || pixels[2]!=255)fail("Unexpected rendered pixels");
    printf("GPU_RENDER_PASS width=64 height=64 red=%u blue=%u fnv1a64=%016llx\n",red,blue,hash);
    glDeleteProgram(program);glDeleteShader(vs);glDeleteShader(fs);
    eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroyContext(display,context);eglDestroySurface(display,surface);eglTerminate(display);
    return 0;
}
