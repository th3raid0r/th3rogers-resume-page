---
title: "Configuring CachyOS for LLMs on Strix Halo"
date: 2025-09-21T14:00:00+07:00
description: A guide on configuring CachyOS for LLM inference on Strix Halo
menu:
  sidebar:
    name: CachyOS on Strix Halo
    identifier: strixhalo-cachyos
    weight: 10
tags: ["llama", "ai", "strix-halo", "linux", "inference", "rocm"]
categories: ["Linux", "AI"]
---

# Introduction 

The AMD Strix Halo platform is a wonderful combination of capabilities! It promises to unlock local AI computing in a way that's more accessible than competitors and help democratize AI. However, this isn't without hurdles, new silicon means new drivers, new SDKs, and updates to existing development platforms (ROCm) -- all of which incur instability, bugs, and inconsistencies between releases. It's the wild west at the moment, and I believe that this existence is best lived on an Arch Linux based platform where the latest packages are only days out from upstream release. 

Consider this:

1. Many guides suggest performing a DKMS install of the amd-xdna driver. However, this has been upstream and included in the kernel as of Linux 6.14. [source](https://www.phoronix.com/news/AMD-NPU-Firmware-Upstream) 
2. Many posts about the chipset (gfx1151) are erroneously marked as un-supported by well meaning community members in upstream projects that _actually do_ support the chipset. (ROCm has a few of these)
3. Some things marked as _not working_ (like hipBLASt support on the lemonade llamacpp build) do have functional workarounds (which I will get into in this guide).
4. As of 09/15/25 AMDVLK has been discontinued, it is often cited as having better inference performance in some cases and often recommended - however, I expect this to change rapidly as the Mesa project's version accelerates.
5. The GTT / Shared memory parameter change has been poorly documented AND seems to have issues working with CachyOS's ZRAM.

However, despite all these changes, there is still one unavoidable truth **this platform is new, requires tinkering, and breaks a lot for inference right now**.

So, how does one get the _best possible experience_? Well, AMD while being short on manpower for truly transformative work, have been good stewards within the open source community. _Despite this_ they have managed to cobble together the following projects:

- [GAIA](https://github.com/amd/gaia) - The friendly frontend (optional - not that functional on Linux yet)
- [Lemonade](https://lemonade-server.ai/) - The more functional backend (critical - especially their llamacpp builds)
- [TheRock](https://github.com/ROCm/TheRock) - gfx1151 tuned ROCm builds (only needed to fix hipBLASt and to support non-lemonade llamacpp builds)

These projects offer the most optimized, cutting edge sets of packages tuned specifically for Strix Halo (gfx1151) and other AMD platforms. They also have discord communities, active contibutors, and help to dispel much of the outdated information about this ecosystem. 

## Supported Features on Linux:

| Inference Device | Driver Support                          | SDK                                             | Lemonade Supported                         |
|------------------|-----------------------------------------|------------------------------------------------|---------------------------------------------|
| NPU              | ✅<sup>Linux v6.14+</sup>                | [mlir-aie](https://github.com/Xilinx/mlir-aie) and ROCm (in progress) | ❌<sup>in progress</sup>              |
| iGPU             | ✅                                      | ROCm 6.4.3+ or Vulkan                          | ✅<sup>llama-cpp</sup>                       |
| CPU              | ✅                                      | Many                                           | ✅ All Backends                              |

# Post-Install

This is not a CachyOS install guide, that process is largely documented on the CachyOS wiki and is a simple process versus a normal Arch install.

## High Level Guidance

**DO NOT**:

- Install any packaged ROCM SDK's (repo or AUR), they aren't recent enough (even the new ROCm 7 release, yes, that branch was cut months ago).
- Use the LTS Kernel unless you need to for emergency boot. 
- Modify system managed config files, CachyOS overwrites any updates by default and will revert your change.

**DO**:

- Use CachyOS Hello to install gaming packages, enable the updater, configuring snapper, etc. (This also gets the necessary vulkan packages)
- Use overrides or an overriding config placement to bypass `cachyos-settings` package caused changes

## Steps

### 1. Shared Memory Configuration

##### Option A: Modprobe.d
Create an `/etc/modprobe.d/amdgpu_llm_optimized.conf` (or whichever name you prefer)

```text
## This specifies GTT by # of 4KB pages:
##   29360128 * 4KB / 1024 / 1024 = 112 GiB
## We leave a buffer of 16GiB on the limit to try to keep your system from excessive swap to ZRAM or OOMing.

options ttm pages_limit=29360128

## Optionally we can pre-allocate any amount of memory. This pool is never accessible to the system.
## You might want to do this to reduce GTT fragmentation, and it might have a perf improvement.
## If you are using your system exclusively to run AI models, just max this out to match your pages_limit.
## This example specifies 60GiB pre-allocated.
#options ttm page_pool_size=12582912
```

##### Option B: Kernel Boot Parameter

Update the boot entry in GRUB/Systemd-Boot/Refind.

This step varies by your preferred boot manager. However the param you'll need to add is `ttm.pages_limit=$DESIREDSIZE`

### 2. Adjust ZRAM

We want to avoid swapping to ZRAM on AI workloads, so we reduce the size and turn down the swappiness. This seems to reduce the negative impact of `mmap` settings in `llama-server`.

Create `/usr/lib/systemd/zram-generator.conf.d` and then a file `10-zram-override.conf` with the contents of:
```ini
[zram0]
compression-algorithm = zstd lz4 (type=huge)
zram-size = ram / 8
swap-priority = 100
fs-type = swap
```

The important part here is `ram / 8` which allocates only 16GB of our physical ram for our ZSWAP. However, we still need to adjust the swappiness. 

### 3. Adjust Swappiness

Run `sudo cp /usr/lib/udev/rules.d/30-zram.rules /etc/udev/rules.d/99-zram.rules` and simply make the contents:
```txt
ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="10", \
    RUN+="/bin/sh -c 'echo N > /sys/module/zswap/parameters/enabled'"
```

This should significantly reduce the system's desire to swap to ZRAM unless there's significant memory pressure. 


### 4. Disable IOMMU (OPTIONAL)

Some users report faster inference with IOMMU disabled. 

This is done at the bootloader level with the kernel parameter `amd_iommu=off` and reportedly gains about 6-7% performance on Prompt Processing. 

# ROCm - TheRock Nightlies

TheRock is a project that automates the drudgery of building the ROCm source yourself, this helps avoid fighting odd compiler issues at least as far as the ROCm stack itself. Additionally, these builds are tuned to specific architectures, and have a smaller filesize compared to the full ROCm releases. 

They hold their releases in an AWS S3 bucket here: https://therock-nightly-tarball.s3.amazonaws.com/

We simply need to fetch the latest release from there which follows the pattern of:`therock-dist-linux-gfx1151-7.0.0rcYYYYMMDD.tar.gz`

So, to download and install it do:

```shell
sudo su
cd /opt
mkdir rocm7.0 && cd rocm7.0
wget https://therock-nightly-tarball.s3.us-east-2.amazonaws.com/therock-dist-linux-gfx1151-7.0.0rc20250913.tar.gz
tar -xzf therock-dist-linux-gfx1151-7.0.0rc20250913.tar.gz
exit
```

Then set the environment variables. You may wish to do this statically with `/etc/environment.d/rocm.conf` or use a bash/zsh function to load various versions on-demand.

The env vars to set are:
```shell
ROCM_PATH=$ROCM_PATH
HIP_PATH=$ROCM_PATH
HIP_PLATFORM=amd
HIP_CLANG_PATH=$ROCM_PATH/llvm/bin
HIP_INCLUDE_PATH=$ROCM_PATH/include
HIP_LIB_PATH=$ROCM_PATH/lib
HIP_DEVICE_LIB_PATH=$HIP_LIB_PATH/llvm/amdgcn/bitcode
PATH="$ROCM_PATH/bin:$HIP_CLANG_PATH:${PATH:-}"
LD_LIBRARY_PATH="$HIP_LIB_PATH:$ROCM_PATH/lib:$ROCM_PATH/lib64:$ROCM_PATH/llvm/lib:${LD_LIBRARY_PATH:-}"
LIBRARY_PATH="$HIP_LIB_PATH:$ROCM_PATH/lib:$ROCM_PATH/lib64:${LIBRARY_PATH:-}"
CPATH="$HIP_INCLUDE_PATH:${CPATH:-}"
PKG_CONFIG_PATH="$ROCM_PATH/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
DCMAKE_C_COMPILER=$ROCM_PATH/llvm/bin/clang
DCMAKE_CXX_COMPILER=$ROCM_PATH/llvm/bin/clang++
```
{{< alert type="info" >}}
_NOTE:_ This also seems to fix the issue where the lemonade build of llamacpp doesn't pick up on the right hipBLASt tensor location. 
{{< /alert >}}


# Lemonade

Lemonade is a server that manages models, deploys llamacpp backends (already pre-optimized in most cases), and serves as a basic reverse proxy to a single llama-server instance. It's good for getting off the ground without much configuration. That being said, we need a few packages. 

## Miniconda

On CachyOS/Arch, miniconda can be found only on the AUR or through a manual install. We'll use the AUR. 

1. Install yay or another AUR helper (Yay is in the CachyOS repos only, vanilla arch needs more steps)

```shell
sudo pacman -S yay
```

2. Then install `miniconda`

```shell
yay -S miniconda
```

Then ensure that you're sourcing the conda.sh folder in your bashrc or zshrc or fish.config.

```shell
[ -f /opt/miniforge/etc/profile.d/conda.sh ] && source /opt/miniforge/etc/profile.d/conda.sh
```

{{< alert type="danger" >}}
CAUTION: Conda Forge isn't always free.

If you are an organization, please know that the Conda Forge repository is a paid product for businesses and enterprises. Their legal team is notorious for shaking down unlicensed usage. You've been warned!
{{< /alert >}}
## Installing Lemonade

Now we create a conda env, install lemonade with some flags, and run our server with the desired backend.

```shell
conda create -n lemon python=3.10
conda activate lemon
sudo update-pciids
pip install lemonade-sdk\[dev,oga-npu,oga-cpu\]
```

Note that these flags differ from the official documentation which only uses the \[dev\] target. I also install oga-cpu and oga-npu just in case lemonade begins to support those on Linux. 

## Running Lemonade

To run with ROCm - execute:
```shell
ROCBLAS_USE_HIPBLASLT=1 lemonade-server-dev --llamacpp rocm
``` 

To run on vulkan instead: 
```shell
lemonade-server-dev --llamacpp vulkan
```

# Advanced Usage

## Lemonade's llamacpp-rocm builds

Rather than using the Lemonade UI, advanced users can download and run the builds themselves. As of 09/21/25 these builds support ROCWMMA acceleration and HIPBLASt support (albiet the packaged version doesn't work quite right with hipBLASt without TheRock nightlies installed and env vars set).

It is possible to perform the compiles yourself, but I've not yet seen a reason to do this outside of upstream contribution. Plus, getting _main_ to compile is unusually difficult at the moment.

[Github Here](https://github.com/lemonade-sdk/llamacpp-rocm)

Running these is as simple as downloading, extracting, `chmod +x` the binaries, and running `llama-server` or `llama-cli` directly as described in the [llamacpp documentation](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#llama-server).

```shell
mkdir ~/llamacpp
wget https://github.com/lemonade-sdk/llamacpp-rocm/releases/download/b1066/llama-b1066-ubuntu-rocm-gfx1151-x64.zip
unzip llama-b1066-ubuntu-rocm-gfx1151-x64.zip -d ./llamacpp
cd llamaccp
chmod +x llama-*

## Run the server
./llama-server -m $MODELPATH/gpt-oss-20b-mxfp4.gguf -ngl 99 --jinja --ctx-size 0 -fa 1
```

You can then use any GUI that supports an oLLAMA backend like GPT-4ALL and other apps. I use LibreChat.
{{< alert type="warning" >}}
WARNING - The `-hf` option is not supported as the llamacpp-rocm build does not include CURL at this time. 
{{< /alert >}}

## What about the NPU?

Ah yes, I mentioned a stack, hardware support, etc, so what gives? Well, the software needs to catch up, it just needs to be written. 

At present, the NPU unit is detected.

```shell
$ lspci | grep -i neural

c4:00.1 Signal processing controller: Advanced Micro Devices, Inc. [AMD] Strix/Krackan/Strix Halo Neural Processing Unit (rev 11)
```

The driver is loaded:
```shell
$ lsmod | grep xdna

amdxdna               176128  0
gpu_sched              69632  2 amdxdna,amdgpu
```

AND `rocminfo` sees it:

```shell
$ rocminfo | grep aie2 -A 4

  Name:                    aie2
  Uuid:                    AIE-XX
  Marketing Name:          AIE-ML
  Vendor Name:             AMD
  Feature:                 AGENT_DISPATCH
```

If you search the strings "aie2" and "AIE-ML" in the ROCm organization you'll see plenty of support being added across the ecosystem. 

**NPU Mini-Conclusion:** 

Anyone who says "ROCm doesn't support xdna/npu/etc" has allowed their knee-jerk reaction against anything new to override reality. They may be well meaning, but ultimately hurt the ability for the project to flourish. So if this is you, STOP!

ROCm support for the NPU is _new, buggy, and under active development at **blistering** speed_. I imagine real NPU use-cases on Linux within 6 months at this rate.