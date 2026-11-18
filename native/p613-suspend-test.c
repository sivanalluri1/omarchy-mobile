/* Bounded, foreground RTC wake/suspend probe for the P613 native RAM system.
 * Does not change the hardware RTC time or disable wake sources. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/rtc.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

static void interrupted(int sig) { (void)sig; }
static int put(const char *path, const char *value) {
    int fd = open(path, O_WRONLY); if (fd < 0) return -1;
    ssize_t n = write(fd, value, strlen(value)); int e = errno;
    close(fd); errno = e; return n == (ssize_t)strlen(value) ? 0 : -1;
}
static double now(clockid_t id) {
    struct timespec t; clock_gettime(id, &t); return t.tv_sec + t.tv_nsec / 1e9;
}
int main(int argc, char **argv) {
    setbuf(stdout, NULL);
    if (argc != 2 || (strcmp(argv[1], "alarm") && strcmp(argv[1], "deep") && strcmp(argv[1], "button") && strcmp(argv[1], "sleep"))) {
        fprintf(stderr, "usage: %s alarm|deep|button|sleep (sleep leaves RTC unchanged)\n", argv[0]); return 2;
    }
    int button = !strcmp(argv[1], "button");
    int timed = strcmp(argv[1], "sleep") != 0;
    int suspending = strcmp(argv[1], "alarm") != 0;
    int seconds = button ? 90 : 20;
    struct utsname u;
    if(uname(&u) || strcmp(u.release,"4.14.357-openela-perf-g21b136df1533")) {
        fprintf(stderr,"refusing unvalidated kernel\n");return 2;
    }
    char count[64]={0};
    if (suspending) {
        char mode[64]={0}; int mf=open("/sys/power/mem_sleep",O_RDONLY);
        if(mf<0 || read(mf,mode,sizeof(mode)-1)<=0 || !strstr(mode,"[deep]")) {
            fprintf(stderr,"deep must already be selected; refusing to change policy\n"); return 1;
        }
        close(mf);
        int c=open("/sys/power/wakeup_count",O_RDONLY|O_NONBLOCK);
        struct sigaction sa={.sa_handler=interrupted}; sigemptyset(&sa.sa_mask);
        sigaction(SIGALRM,&sa,NULL); alarm(3);
        ssize_t n=c<0?-1:read(c,count,sizeof(count)-1); alarm(0); if(c>=0)close(c);
        if(n<=0) {perror("active wake source / wakeup_count");return 3;}
    }
    int fd = -1;
    struct rtc_wkalrm old = {0};
    if (timed) {
    fd = open("/dev/rtc0", O_RDWR);
    struct rtc_time r; struct rtc_wkalrm a = {0};
    if (fd < 0 || ioctl(fd, RTC_RD_TIME, &r) || ioctl(fd, RTC_WKALM_RD, &old)) {
        perror("read RTC"); return 1;
    }
    if (old.enabled) { fprintf(stderr, "refusing to replace active RTC alarm\n"); return 1; }
    struct tm t = {.tm_sec=r.tm_sec,.tm_min=r.tm_min,.tm_hour=r.tm_hour,
        .tm_mday=r.tm_mday,.tm_mon=r.tm_mon,.tm_year=r.tm_year};
    time_t target = timegm(&t) + seconds; struct tm out; gmtime_r(&target, &out);
    a.time = (struct rtc_time){.tm_sec=out.tm_sec,.tm_min=out.tm_min,.tm_hour=out.tm_hour,
        .tm_mday=out.tm_mday,.tm_mon=out.tm_mon,.tm_year=out.tm_year}; a.enabled=1;
    if (ioctl(fd, RTC_WKALM_SET, &a)) { perror("arm RTC"); return 1; }
    printf("RTC armed for +%d seconds\n", seconds);
    } else printf("RTC unchanged; waiting for hardware wake\n");
    int rc=0; double b=now(CLOCK_BOOTTIME), m=now(CLOCK_MONOTONIC);
    if (!strcmp(argv[1], "alarm")) {
        struct pollfd p={.fd=fd,.events=POLLIN};
        int n=poll(&p,1,30000); unsigned long flags=0;
        if (n != 1 || read(fd,&flags,sizeof(flags)) != sizeof(flags) || !(flags & RTC_AF)) {
            fprintf(stderr,"RTC alarm did not arrive\n"); rc=1;
        } else printf("RTC alarm interrupt received\n");
    } else {
        if(put("/sys/power/wakeup_count",count)) {
            int e=errno; perror("prepare suspend");
            rc=(e==EINVAL || e==EAGAIN || e==EBUSY || e==EINTR)?3:1;
        } else {
            sync(); printf("Entering mem/deep\n");
            if(put("/sys/power/state","mem")) {int e=errno;perror("suspend");rc=e==EBUSY?4:1;}
        }
    }
    double slept=(now(CLOCK_BOOTTIME)-b)-(now(CLOCK_MONOTONIC)-m);
    if(suspending && slept<((button || !timed) ? 0.5 : 10.0) && rc==0) rc=1;
    printf("boottime_elapsed=%.3f monotonic_elapsed=%.3f suspended_seconds=%.3f\n",
        now(CLOCK_BOOTTIME)-b,now(CLOCK_MONOTONIC)-m,
        (now(CLOCK_BOOTTIME)-b)-(now(CLOCK_MONOTONIC)-m));
    /* Clear only our alarm; restore the previous disabled alarm contents. */
    if(timed) {
    if(ioctl(fd,RTC_AIE_OFF,0)) {perror("disable RTC alarm");rc=1;}
    if(ioctl(fd,RTC_WKALM_SET,&old)) {perror("restore disabled alarm");rc=1;}
    close(fd);
    }
    return rc;
}
