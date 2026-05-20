#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

static void setup_console(void)
{
    int fd = open("/dev/console", O_RDWR);
    if (fd < 0)
        fd = open("/dev/ttyS0", O_RDWR);
    if (fd < 0)
        return;

    dup2(fd, STDIN_FILENO);
    dup2(fd, STDOUT_FILENO);
    dup2(fd, STDERR_FILENO);
    if (fd > STDERR_FILENO)
        close(fd);

    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
}

static void print_file(const char *path)
{
    char buffer[512];
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        printf("init: could not open %s: %s\n", path, strerror(errno));
        return;
    }

    for (;;) {
        ssize_t n = read(fd, buffer, sizeof(buffer));
        if (n <= 0)
            break;
        ssize_t off = 0;
        while (off < n) {
            ssize_t written = write(STDOUT_FILENO, buffer + off, (size_t)(n - off));
            if (written <= 0)
                break;
            off += written;
        }
    }

    close(fd);
}

int main(void)
{
    mkdir("/proc", 0555);
    mkdir("/sys", 0555);
    mkdir("/dev", 0755);
    mount("proc", "/proc", "proc", 0, "");
    mount("sysfs", "/sys", "sysfs", 0, "");
    mount("devtmpfs", "/dev", "devtmpfs", 0, "");
    setup_console();

    printf("\nCVA6 ZCU111 Linux initramfs reached\n");
    printf("init: pid=%ld\n", (long)getpid());
    printf("\n/proc/cpuinfo:\n");
    print_file("/proc/cpuinfo");

    for (unsigned long beat = 0;; beat++) {
        printf("init: heartbeat %lu\n", beat);
        sleep(5);
    }
}
