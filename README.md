# Quick Start

```bash
nix-shell # Enter nix-shell 
```

```bash
make all
sudo insmod hotfix-kvadra-touchpad.ko
```

# hotfix-kvadra-touchpad

This simple kernel module provides a hotfix for touchpad issues
KVADRA NAU LE14U and similar notebooks.

## The problem

On these notebooks, the touchpad stops functioning after some idle time
(10-30 minutes).

The notebook is equipped with an Intel i5-1235U CPU, four Intel
Corporation Alder Lake PCH Serial IO I2C controllers, and a SYNA3602
touchpad connected via the I2C serial bus.

The I2C controllers use interrupts 27, 31, 32, and 40, which are shared
between the `i2c_designware` and `idma64` modules. However, only IRQ #27
appears to be actively used.

Both `/sys/devices/pci0000:00/0000:00:19.0/dma/dma3chan0/bytes_transferred`
and `/sys/devices/pci0000:00/0000:00:19.0/dma/dma3chan1/bytes_transferred`
show "0", indicating that idma64 is not actually in use. The only module
utilizing these interrupts is `i2c_designware` at IRQ #27.

Kernel log (dmesg) shows the following lines:

```
RSP: 0018:ffffa7d5001b7e80 EFLAGS: 00000246
RAX: ffff93ab5f700000 RBX: ffff93ab5f761738 RCX: 000000000000001f
RDX: 0000000000000002 RSI: 0000000033483483 RDI: 0000000000000000
RBP: 0000000000000001 R08: 000004c7d586da52 R09: 0000000000000007
R10: 000000000000002a R11: ffff93ab5f744f04 R12: ffffffffb964fe60
R13: 000004c7d586da52 R14: 0000000000000001 R15: 0000000000000000
 cpuidle_enter+0x2d/0x40
 do_idle+0x1ad/0x210
 cpu_startup_entry+0x29/0x30
 start_secondary+0x11e/0x140
 common_startup_64+0x13e/0x141
 </TASK>
handlers:
[<00000000fa02aea8>] idma64_irq [idma64]
[<00000000d22a6968>] i2c_dw_isr
Disabling IRQ #27
```

## Analysis

Examining the source code for the i2c_dw_isr routine (located in
drivers/i2c/busses/i2c-designware-master.c), we find the following code:

```
static irqreturn_t i2c_dw_isr(int this_irq, void *dev_id)
{
        struct dw_i2c_dev *dev = dev_id;
        unsigned int stat, enabled;

        regmap_read(dev->map, DW_IC_ENABLE, &enabled);
        regmap_read(dev->map, DW_IC_RAW_INTR_STAT, &stat);
        if (!enabled || !(stat & ~DW_IC_INTR_ACTIVITY))
                return IRQ_NONE;
        if (pm_runtime_suspended(dev->dev) || stat == GENMASK(31, 0))
                return IRQ_NONE;

        . . . . .

        return IRQ_HANDLED;
}
```

It appears that when an interrupt occurs, i2c_dw_isr fails to recognize it
as its own (which may be normal due to the asynchronous nature of
interrupt delivery; spurious interrupts can occasionally occur) and
returns `IRQ_NONE`. This leads the kernel to consider the interrupt
unhandled and disable it, resulting in the touchpad (and the entire I2C
stack, though the touchpad issue is more noticeable) ceasing to
function.

We encountered this issue in ROSA Linux with kernel version 6.12.4, and
it persists in version 6.12.10.

This issue did not exist in kernel version 6.6.47.

A similar issue has been reported for Arch Linux against kernel version
6.12.8:

* <https://bbs.archlinux.org/viewtopic.php?id=302348>

## The Solution

This simple module registers itself as a handler for all IRQs used by
the I2C controllers installed in the system.

The added interrupt handler does nothing but always returns `IRQ_HANDLED`,
effectively preventing the kernel from disabling these interrupts.

Please note that this approach may yield one of two results:

* it could fix the problem, in case that unhanded interrupt detection
    is false positive, as in our case
* or it could cause interrupt storm if the same interrupt occurs
    repeatedly without being recognized or handled (which is why the kernel
    automatically disables unhandled interrupts).

In our case, this solution has proven reliable and effectively resolves
the initial problem.

<!-- vim:ts=8:sw=4:et:textwidth=72
-->
