#include <unistd.h>

int main() {
    execl("/usr/sbin/systemctl", "/usr/sbin/systemctl", "start", "backup.service", NULL);
}
