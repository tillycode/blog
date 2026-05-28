---
date: '2026-05-23T00:54:35+08:00'
title: Nix入坑指南
tags: [Nix]
---

若说到当代编程领域的神教，我会想起这3样：Rust、Arch Linux以及Nix。
这3个神教都得有一些魔力，吸引信徒虔诚追随。
本文会先介绍一些Nix入门概念和学习指引，然后讲解一些实用的Nix写法，最后会探讨一下Nix的原理。

<!--more-->

## 介绍

你可以按照[Download | Nix & NixOS](https://nixos.org/download/)中描述的安装Nix，推荐使用multi-user installation。
安装后，我们通常会编辑`/etc/nix/nix.conf`开启下面两个实验特性。

```properties
experimental-features = nix-command flakes
```

这些特性虽然被标记为“实验”，Nix开发团队并不保证CLI的稳定性。
但确实很好用，社区内也已经基于此构造了庞大的生态。后文都会假设这两个选项已经开启。

### 作为一个包管理器

让我们来介绍一下Nix吧。Nix是一个**包管理器**。
你可以像apt、yum、pacman那样命令式地安装软件。

```console
$ nix profile add nixpkgs#kubectl
```

这个命令无需用root身份运行，只为当前用户安装软件。
当然要真正使用Nix提供的软件，你需要配置一下shell，把`~/.nix-profile/bin`添加到`PATH`路径即可。

```shell
export PATH=~/.nix-profile/bin:$PATH
```

不同于其他包管理器，Nix支持**原子回滚**。我们会在后文介绍一下Nix是如何实现这个魔法的。

```console
$ nix profile rollback
```

它还支持你**ad-hoc运行一个软件**，类似于`npx`，`go run`那样。
你可以配置上Nix的GC daemon。这样这些ad-hoc下载的软件过一阵子会被垃圾回收。

```console
$ nix run nixpkgs#bun
```

甚至你可以直接运行GitHub上发布的一个软件。
当然如果不添加上游二进制源时，Nix会按照仓库中的Nix代码构建整个应用。

```console
$ nix run github:nix-community/nixos-anywhere -- --help
```

自然而然地，你就可以用Nix把所有的依赖都声明在自己的脚本里。
只要用户装了Nix，就不用担心脚本中的依赖不存在了。
这使得我们可以放心使用bleeding edge的软件。
如果还担心软件本身不稳定，你可以修改nix-shell参数，固定nixpkgs版本。
这样就相当于固定了所有软件版本，能拥有极致的可复现性。

```nu {hl_lines=[2]}
#!/usr/bin/env nix-shell
#!nix-shell -i nu -p nushell curl

let ip = (^curl -s "https://api.ipify.org?format=json" | from json).ip
print $"Your IP is ($ip)"
```

这里提到的nixpkgs是刚才所有命令依赖的一个GitHub仓库。
它是个巨大的monorepo，使用Nix代码描述了刚才提到的所有软件的构建方式。

### 作为一个编程语言

### NixOS介绍
