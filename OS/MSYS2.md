# 1. 安装

下载地址：https://www.msys2.org/



```bash
# 安装 GCC
pacman -S mingw-w64-ucrt-x86_64-gcc

# 安装 mingw-toolchain
pacman -S mingw-w64-x86_64-toolchain

pacman -S mingw-w64-ucrt-x86_64-toolchain
```



添加路径到到环境变量PATH中：

```bash
C:\msys64\mingw64\bin
```



# 2. 环境对比

| 环境 | 编译器 | CRT/运行库 | 特点 | 适用场景 |
| ---- | ------ | ---------- | ---- | -------- |
| **MSYS2** | GCC  | msys-2.0.dll | **POSIX 仿真环境**，基于 Cygwin，不是纯 Windows              | 运行工具链，写构建脚本，不推荐编译 Windows 原生应用 |
| **MINGW64** | GCC  | msvcrt.dll | **MinGW-w64 + msvcrt**（Microsoft Visual C Runtime，老版本 CRT） | 与传统 GCC 一致，但运行库比较老，适合兼容 WIN XP/7 或老程序 |
| **UCRT64** | GCC  | ucrtbase.dll | **MinGW-w64 + UCRT**（Universal CRT，Windows 10 引入的现代运行库） | Windows 10/11 应用，现代 C/C++ |
| **CLANG64** | Clang | ucrtbase.dll | **LLVM/Clang + MinGW-w64**（UCRT），兼容 MSVC ABI | 跨平台项目、需要 Clang 特性的工程 |



MSYS2 的 `pacman` 包分几类，名字里就能看出目标环境：

- `mingw-w64-x86_64-XXX` → 安装到 **MINGW64 前缀** (`/mingw64/`)
- `mingw-w64-ucrt-x86_64-XXX` → 安装到 **UCRT64 前缀** (`/ucrt64/`)
- `mingw-w64-clang-x86_64-XXX` → 安装到 **CLANG64 前缀** (`/clang64/`)
- `XXX`（没带前缀的）→ 安装到 **MSYS2 自身环境** (`/usr/`)



# 3. 安装 Rust

在 msys2 中输入命令安装 rust

```bash
$ curl https://sh.rustup.rs -sSf | sh
info: downloading installer

Rust Visual C++ prerequisites

Rust requires a linker and Windows API libraries but they don't seem to be
available.

These components can be acquired through a Visual Studio installer.

1) Quick install via the Visual Studio Community installer
   (free for individuals, academic uses, and open source).

2) Manually install the prerequisites
   (for enterprise and advanced users).

3) Don't install the prerequisites
   (if you're targeting the GNU ABI).

>2


You can acquire the build tools by installing Microsoft Visual Studio.

  https://visualstudio.microsoft.com/downloads/

Check the box for "Desktop development with C++" which will ensure that the
needed components are installed. If your locale language is not English,
then additionally check the box for English under Language packs.

For more details see:

  https://rust-lang.github.io/rustup/installation/windows-msvc.html

Install the C++ build tools before proceeding.

If you will be targeting the GNU ABI or otherwise know what you are
doing then it is fine to continue installation without the build
tools, but otherwise, install the C++ build tools before proceeding.

Continue? (y/N)
y


Welcome to Rust!

This will download and install the official compiler for the Rust
programming language, and its package manager, Cargo.

Rustup metadata and toolchains will be installed into the Rustup
home directory, located at:

  C:\Users\elihe\.rustup

This can be modified with the RUSTUP_HOME environment variable.

The Cargo home directory is located at:

  C:\Users\elihe\.cargo

This can be modified with the CARGO_HOME environment variable.

The cargo, rustc, rustup and other commands will be added to
Cargo's bin directory, located at:

  C:\Users\elihe\.cargo\bin

This path will then be added to your PATH environment variable by
modifying the PATH registry key at HKEY_CURRENT_USER\Environment.

You can uninstall at any time with rustup self uninstall and
these changes will be reverted.

Current installation options:


   default host triple: x86_64-pc-windows-msvc
     default toolchain: stable (default)
               profile: default
  modify PATH variable: yes

1) Proceed with standard installation (default - just press enter)
2) Customize installation
3) Cancel installation
>2

I'm going to ask you the value of each of these installation options.
You may simply press the Enter key to leave unchanged.

Default host triple? [x86_64-pc-windows-msvc]
x86_64-pc-windows-gnu

Default toolchain? (stable/beta/nightly/none) [stable]


Profile (which tools and data to install)? (minimal/default/complete) [default]


Modify PATH variable? (Y/n)
Y


Current installation options:


   default host triple: x86_64-pc-windows-gnu
     default toolchain: stable
               profile: default
  modify PATH variable: yes

1) Proceed with selected options (default - just press enter)
2) Customize installation
3) Cancel installation
1
```



```powershell
PS C:\Users\elihe> rustup update
info: syncing channel updates for 'stable-x86_64-pc-windows-gnu'
info: checking for self-update

  stable-x86_64-pc-windows-gnu unchanged - rustc 1.89.0 (29483883e 2025-08-04)

info: cleaning up downloads & tmp directories
PS C:\Users\elihe> rustc -V
rustc 1.89.0 (29483883e 2025-08-04)
PS C:\Users\elihe>
```

