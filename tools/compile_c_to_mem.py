#!/usr/bin/env python3
import argparse
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


LINKER_SCRIPT = """ENTRY(_start)

PHDRS
{{
    text PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}}

SECTIONS
{{
    . = 0x{text_base:08x};
    .text : {{
        *(.text.startup*)
        *(.text*)
    }} :text

    . = ALIGN(4);
    .rodata : {{
        *(.srodata*)
        *(.rodata*)
    }} :text

    . = ALIGN(4);
    .data : {{
        *(.sdata*)
        *(.data*)
    }} :data

    .bss : {{
        *(.sbss*)
        *(.bss*)
        *(COMMON)
    }} :data

    /DISCARD/ : {{
        *(.eh_frame*)
    }}
}}

PROVIDE(__stack_top = 0x{stack_top:08x});
"""


STARTUP_ASM = """.section .text.startup
.global _start
_start:
    lui sp, %hi(__stack_top)
    addi sp, sp, %lo(__stack_top)
    call {entry}
1:
    jal zero, 1b
"""


@dataclass
class Section:
    name: str
    section_type: str
    address: int
    size: int
    flags: str


def parse_int(value):
    return int(value, 0)


def require_tool(name):
    tool = shutil.which(name)
    if tool is None:
        raise SystemExit(f"error: required tool not found in PATH: {name}")
    return tool


def run(command, stdout=None):
    subprocess.run(command, check=True, stdout=stdout)


def capture(command):
    return subprocess.run(command, check=True, text=True, capture_output=True).stdout


def write_linker_script(path, text_base, stack_top):
    path.write_text(
        LINKER_SCRIPT.format(
            text_base=text_base,
            stack_top=stack_top,
        )
    )


def write_startup(path, entry):
    path.write_text(STARTUP_ASM.format(entry=entry))


def read_sections(readelf, elf):
    output = capture([readelf, "-SW", str(elf)])
    pattern = re.compile(
        r"\[\s*\d+\]\s+(\S+)\s+(\S+)\s+([0-9a-fA-F]+)\s+"
        r"[0-9a-fA-F]+\s+([0-9a-fA-F]+)\s+\S+\s+(\S+)"
    )

    sections = []
    for line in output.splitlines():
        match = pattern.search(line)
        if match is None:
            continue

        sections.append(
            Section(
                name=match.group(1),
                section_type=match.group(2),
                address=int(match.group(3), 16),
                size=int(match.group(4), 16),
                flags=match.group(5),
            )
        )

    return sections


def should_copy_to_memory(section):
    return section.size > 0 and "A" in section.flags and section.section_type != "NOBITS"


def extract_section(objcopy, elf, section, temp_dir):
    output = temp_dir / f"{section.name.strip('.')}.bin"
    run([objcopy, "-O", "binary", "-j", section.name, str(elf), str(output)])
    return output.read_bytes()


CPU_WORD_BYTES = 4


def build_memory_image(objcopy, elf, sections, memory_base, memory_depth_words, memory_word_bytes):
    memory = bytearray(memory_depth_words * memory_word_bytes)
    used_bytes = 0

    with tempfile.TemporaryDirectory(prefix="compile_c_to_mem_") as temp:
        temp_dir = Path(temp)

        for section in sections:
            if not should_copy_to_memory(section):
                continue

            start = section.address - memory_base
            end = start + section.size

            if start < 0:
                raise SystemExit(
                    f"error: section {section.name} at 0x{section.address:x} is below "
                    f"memory base 0x{memory_base:x}"
                )

            if end > len(memory):
                needed_words = (end + memory_word_bytes - 1) // memory_word_bytes
                raise SystemExit(
                    f"error: section {section.name} needs memory depth {needed_words}, "
                    f"but --memory-depth is {memory_depth_words}"
                )

            data = extract_section(objcopy, elf, section, temp_dir)
            memory[start:end] = data[: section.size]
            used_bytes = max(used_bytes, end)

    return memory, (used_bytes + memory_word_bytes - 1) // memory_word_bytes


def memory_to_words(memory, memory_word_bytes):
    words = []
    for offset in range(0, len(memory), memory_word_bytes):
        words.append(int.from_bytes(memory[offset : offset + memory_word_bytes], "little"))
    return words


def write_gowin_mi(path, words, depth, data_width):
    hex_digits = data_width // 4
    path.write_text(
        "#File_format=Hex\n"
        f"#Address_depth={depth}\n"
        f"#Data_width={data_width}\n"
        + "\n".join(f"{word:0{hex_digits}X}" for word in words)
        + "\n"
    )


def compile_source(args, paths, tools):
    common_flags = [
        "-march=rv32i",
        "-mabi=ilp32",
        "-ffreestanding",
        "-nostdlib",
        "-fno-builtin",
        "-fno-asynchronous-unwind-tables",
        "-fno-unwind-tables",
        "-msmall-data-limit=0",
        args.opt,
    ]

    run([tools["gcc"], *common_flags, "-S", str(args.source), "-o", str(paths["assembly"])])
    run([tools["gcc"], *common_flags, "-c", str(args.source), "-o", str(paths["object"])])
    run([tools["gcc"], *common_flags, "-c", str(paths["startup"]), "-o", str(paths["startup_object"])])

    with paths["object_dump"].open("w") as output:
        run([tools["objdump"], "-dr", "-M", "no-aliases", str(paths["object"])], stdout=output)

    link_command = [
        tools["gcc"],
        *common_flags,
        "-nostartfiles",
        f"-Wl,-T,{paths['linker_script']}",
        str(paths["startup_object"]),
        str(paths["object"]),
        "-o",
        str(paths["elf"]),
    ]

    if args.libgcc:
        link_command.append("-lgcc")

    run(link_command)

    with paths["linked_dump"].open("w") as output:
        run([tools["objdump"], "-d", "-M", "no-aliases", str(paths["elf"])], stdout=output)


def make_output_paths(out_dir, name):
    return {
        "assembly": out_dir / f"{name}.s",
        "object": out_dir / f"{name}.o",
        "elf": out_dir / f"{name}.elf",
        "object_dump": out_dir / f"{name}.objdump",
        "linked_dump": out_dir / f"{name}.linked.objdump",
        "linker_script": out_dir / f"{name}.ld",
        "startup": out_dir / f"{name}_start.S",
        "startup_object": out_dir / f"{name}_start.o",
        "memory_init": out_dir / f"{name}.mi",
    }


def parse_args():
    parser = argparse.ArgumentParser(
        description="Compile freestanding RV32I C into one Gowin memory init .mi file."
    )
    parser.add_argument("source", type=Path)
    parser.add_argument("-o", "--out-dir", type=Path, default=Path("testcases/build"))
    parser.add_argument("--name", help="output stem; defaults to input filename stem")
    parser.add_argument("--entry", default="main", help="C entry function called by the startup stub")
    parser.add_argument("--text-base", type=parse_int, default=0x00000000)
    parser.add_argument("--memory-base", type=parse_int, default=0x00000000)
    parser.add_argument("--memory-depth", type=int, default=8192, help="memory words at --data-width")
    parser.add_argument("--data-width", type=int, default=32, choices=(32, 64), help="Gowin memory data width")
    parser.add_argument("--opt", default="-O2")
    parser.add_argument("--libgcc", action="store_true")
    parser.add_argument("--keep-ld", action="store_true")
    parser.add_argument("--keep-startup", action="store_true")
    parser.add_argument("--gcc", default="riscv64-unknown-elf-gcc")
    parser.add_argument("--objcopy", default="riscv64-unknown-elf-objcopy")
    parser.add_argument("--objdump", default="riscv64-unknown-elf-objdump")
    parser.add_argument("--readelf", default="riscv64-unknown-elf-readelf")
    return parser.parse_args()


def main():
    args = parse_args()
    if not args.source.exists():
        raise SystemExit(f"error: source file not found: {args.source}")
    memory_word_bytes = args.data_width // 8

    tools = {
        "gcc": require_tool(args.gcc),
        "objcopy": require_tool(args.objcopy),
        "objdump": require_tool(args.objdump),
        "readelf": require_tool(args.readelf),
    }

    name = args.name or args.source.stem
    args.out_dir.mkdir(parents=True, exist_ok=True)
    paths = make_output_paths(args.out_dir, name)

    stack_top = args.memory_base + (args.memory_depth * memory_word_bytes)
    write_linker_script(paths["linker_script"], args.text_base, stack_top)
    write_startup(paths["startup"], args.entry)
    compile_source(args, paths, tools)

    sections = read_sections(tools["readelf"], paths["elf"])
    memory, used_words = build_memory_image(
        tools["objcopy"],
        paths["elf"],
        sections,
        args.memory_base,
        args.memory_depth,
        memory_word_bytes,
    )
    write_gowin_mi(
        paths["memory_init"],
        memory_to_words(memory, memory_word_bytes),
        args.memory_depth,
        args.data_width,
    )

    if not args.keep_ld:
        paths["linker_script"].unlink()
    if not args.keep_startup:
        paths["startup"].unlink()
        paths["startup_object"].unlink()

    print(f"source: {args.source}")
    print(f"assembly: {paths['assembly']}")
    print(f"elf: {paths['elf']}")
    used_cpu_words = (used_words * memory_word_bytes + CPU_WORD_BYTES - 1) // CPU_WORD_BYTES
    print(f"Gowin fpga unified mi: {paths['memory_init']} ({used_words} / {args.memory_depth} {args.data_width}-bit words used, {used_cpu_words} 32-bit CPU words)")
    print(f"linked disassembly: {paths['linked_dump']}")


if __name__ == "__main__":
    main()
