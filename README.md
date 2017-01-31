A project for writing various [packer](http://packer.io/) templates. ISO referenced in packer file is from [the devuan files repository](https://files.devuan.org/devuan_jessie_beta) which you could specify directly in the packer file (packer will then download the file directly itself, but that's not so convenient if your packer cache directory is cleaned up automatically, so the URL specified in the file points to a file on disk locally).

I am in the progress of using packer to build a .box file to use with [vagrant](http://vagrantup.com) in combination with the [VMware provider](https://www.vagrantup.com/vmware/#buy-now). To initiate a build:

```
packer verify devuan-packer.json
packer build devuan-packer.json
```

Packer will generate a VMX file and start VMware Workstation locally (I'm running with VMware Workstation 11). After that, packer will send keyboard commands (see devuan-packer.json) to initiate an OS installation. My plan is to use the `http_directory` directive to serve a Debian Jessie compatible preseed file and use `boot_command` arguments to do the early preseed kick-off.
