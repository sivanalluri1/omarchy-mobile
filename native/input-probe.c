/* Enumerate classified input and optionally count a bounded interaction trial. */
#include <errno.h>
#include <fcntl.h>
#include <libinput.h>
#include <libudev.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>
static int open_device(const char *path,int flags,void *data) { (void)data; int fd=open(path,flags|O_CLOEXEC); return fd>=0?fd:-errno; }
static void close_device(int fd,void *data) { (void)data;close(fd); }
static const struct libinput_interface interface={open_device,close_device};
static double now(void) { struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9; }
int main(int argc,char **argv) {
  unsigned duration=0;
  if(argc==3 && strcmp(argv[1],"--observe-seconds")==0) duration=(unsigned)atoi(argv[2]);
  else if(argc!=1) return 2;
  if(duration>120) return 2;
  setvbuf(stdout,NULL,_IOLBF,0);
  struct udev *udev=udev_new();
  struct libinput *input=libinput_udev_create_context(&interface,NULL,udev);
  if(!input || libinput_udev_assign_seat(input,"seat0")!=0) return 1;
  unsigned devices=0,touch_down=0,touch_motion=0,touch_up=0,pen_motion=0,pen_tip=0,pen_proximity=0;
  double pressure_min=1.0,pressure_max=0.0,until=now()+duration;
  do {
    libinput_dispatch(input);
    struct libinput_event *event;
    while((event=libinput_get_event(input))) {
      enum libinput_event_type type=libinput_event_get_type(event);
      if(type==LIBINPUT_EVENT_DEVICE_ADDED) {
        struct libinput_device *d=libinput_event_get_device(event);
        printf("INPUT_DEVICE name=%s node=%s touch=%d tablet=%d keyboard=%d\n",
          libinput_device_get_name(d),libinput_device_get_sysname(d),
          libinput_device_has_capability(d,LIBINPUT_DEVICE_CAP_TOUCH),
          libinput_device_has_capability(d,LIBINPUT_DEVICE_CAP_TABLET_TOOL),
          libinput_device_has_capability(d,LIBINPUT_DEVICE_CAP_KEYBOARD));
        devices++;
      }
      if(type==LIBINPUT_EVENT_TOUCH_DOWN)touch_down++;
      if(type==LIBINPUT_EVENT_TOUCH_MOTION)touch_motion++;
      if(type==LIBINPUT_EVENT_TOUCH_UP)touch_up++;
      if(type==LIBINPUT_EVENT_TABLET_TOOL_PROXIMITY)pen_proximity++;
      if(type==LIBINPUT_EVENT_TABLET_TOOL_TIP)pen_tip++;
      if(type==LIBINPUT_EVENT_TABLET_TOOL_AXIS)pen_motion++;
      if(type==LIBINPUT_EVENT_TABLET_TOOL_AXIS || type==LIBINPUT_EVENT_TABLET_TOOL_TIP) {
        double p=libinput_event_tablet_tool_get_pressure(libinput_event_get_tablet_tool_event(event));
        if(p<pressure_min)pressure_min=p;
        if(p>pressure_max)pressure_max=p;
      }
      libinput_event_destroy(event);
    }
    if(duration) { struct pollfd fd={libinput_get_fd(input),POLLIN,0};poll(&fd,1,100); }
  } while(now()<until);
  printf("INPUT_SUMMARY devices=%u touch_down=%u touch_motion=%u touch_up=%u pen_proximity=%u pen_tip=%u pen_motion=%u pressure_min=%.4f pressure_max=%.4f\n",
    devices,touch_down,touch_motion,touch_up,pen_proximity,pen_tip,pen_motion,pressure_min,pressure_max);
  libinput_unref(input);udev_unref(udev);
  return devices?0:1;
}
