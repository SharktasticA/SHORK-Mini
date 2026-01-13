######################################################
## Python helper functions for build.sh             ##
######################################################
## Kali (sharktastica.co.uk)                        ##
######################################################



import os



def build_pci_ids():
    input = None
    buf = []

    term_whitelist = [
        "gpu", "graphics", "vga", "3d", "display", "radeon", "geforce", "quadro", "tesla", "instinct", "firepro", "arc", "iris", "uhd", "xe ", "framebuffer"
    ]

    term_blacklist = [
        "audio", "ethernet", "lan", "wireless", "usb", "nvme", "sata", "ahci", "raid", "scsi", "sd", "mmc", "ufs", "flash", "chipset", "lpc", "pch", "southbridge", "northbridge", "host bridge", "pci bridge", "pcie bridge", "root port", "isa bridge", "power", "thermal", "clock", "voltage", "fan", "sensor", "management", "engine", "mei", "psp", "smu", "firmware", "secure", "iommu", "dma", "interrupt", "ioapic", "serial", "uart", "spi", "i2c", "gpio", "smbus", "virtual", "virtual function", "vf", "test", "debug", "dummy", "null", "motherboard", "mainboard", "board", "platform", "system", "processor", "xeon", "atom", "server", "family", "port", "connection", "gigabit", "laptop", "notebook", "mobility", "latitude", "centrino", "wi-fi", "nvm express", "thunderbolt", "fabric", "interconnect", "link", "switch", "endpoint", "upstream", "downstream", "memory", "cache", "ddr", "lpddr", "controller hub", "pmu", "punit", "pwr", "energy", "throttle", "ras", "error", "parity", "ecc", "scrubber", "watchdog", "telemetry", "pll", "tsc", "time", "timer", "trace", "profiling", "perf", "performance monitor", "logic analyzer", "acpi", "apic", "boot", "bios interface", "type-c", "usb4", "retimer", "mux", "alt mode", "reference", "evaluation", "engineering", "sample", "es", "oem", "register", "network", "block device", "tpu", "virtio", "neural", "pcmcia", "cardbus", "ide", "decoder", "fax", "host", "modem", "firewire", "north bridge", "mac", "can bus", "pci-e", "qemu", "heci", "dram", "amplicon", "motion control", "scratch", "opi ", "zpi ", "i2s", "traffic", "82379ab", "82437fx", "legacy bridge", "80960rm"
    ]

    vendor_whitelist = [
        "3dfx interactive", "advanced micro devices", "alliance semiconductor corporation", "ambarella", "aspeed technology", "cirrus logic", "google", "hangzhou hikvision digital technology", "intel corporation", "kinetic technologies", "matrox electronics systems", "neomagic corporation", "nvidia corporation", "number nine visual technology", "red hat", "s3 graphics", "sgs thomson microelectronics", "silicon integrated systems", "trident microsystems", "via technologies", "vmware", "western digital", "wch.cn", "zhaoxin", "loongson technology", "display controller", "unclassified device", "amp", "datacube", "ziatech", "rdc semiconductor", "xdx computing technology", "3dlabs"
    ]

    for path in ("/usr/share/misc/pci.ids", "/usr/share/hwdata/pci.ids"):
        if os.path.isfile(path) and os.access(path, os.R_OK):
            input = path
            break

    if input is None:
        return

    current_vendor = None

    with open(input, "r", encoding="utf-8", errors="replace") as file:
        for line in file:
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith("#"):
                continue

            lower = stripped.lower()
            if any(term in lower for term in term_blacklist) and not any(term in lower for term in term_whitelist) and not any(term in lower for term in vendor_whitelist):
                continue

            tabs = len(line) - len(line.lstrip("\t"))

            if tabs == 0:
                current_vendor = {
                    "line": line.rstrip("\n"),
                    "devices": []
                }
                buf.append(current_vendor)
            else:
                if current_vendor is not None and tabs == 1:
                    current_vendor["devices"].append(line.rstrip("\n"))

    output = os.path.join(os.path.dirname(__file__), "build/root/usr/share/misc/pci.ids")
    os.makedirs(os.path.dirname(output), exist_ok=True)

    with open(output, "w", encoding="utf-8") as f:
        for vendor in buf:
            if not vendor["devices"]:
                continue

            vendor_name = vendor["line"].lower()
            if not any(manu in vendor_name or vendor_name in manu for manu in vendor_whitelist):
                continue

            f.write(vendor["line"] + "\n")
            for child in vendor["devices"]:
                f.write(child + "\n")
