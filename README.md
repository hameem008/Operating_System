# Operating_System
Assignments of the course Oprating System.

xv6: Resources
[Prerequisite tools](https://pdos.csail.mit.edu/6.828/2022/tools.html)

Cloning codebase:
git clone https://github.com/shuaibw/xv6-riscv --depth=1

Compile and run (from inside xv6-riscv directory):
make clean; make qemu

Generating patch (from inside xv6-riscv directory):
git add --all; git diff HEAD > <patch file name>

e.g.: git add --all; git diff HEAD > ../test.patch

Applying patch:
git apply --whitespace=fix <patch file name>
e.g.: git apply --whitespace=fix ../test.patch

Cleanup git directory:
git clean -fdx; git reset --hard

[Explanation of source code](https://www.youtube.com/watch?v=fWUJKH0RNFE&list=PLbtzT1TYeoMhTPzyTZboW_j7TPAnjv9XB)
