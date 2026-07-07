#!/usr/bin/env python3
"""
RISC Assembler - Converts RISC assembly code to binary machine code
Based on the 32-bit RISC CPU instruction set

Supports standard assembler directives:
- .text: Indicates the start of code section
"""

import re
import sys

class RiscAssembler:
    def __init__(self):
        # Define instruction formats and opcodes
        self.opcodes = {
            # R-type instructions
            'add': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b000, 'funct7': 0b0000000},
            'sub': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b000, 'funct7': 0b0100000},
            'and': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b111, 'funct7': 0b0000000},
            'or':  {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b110, 'funct7': 0b0000000},
            'xor': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b100, 'funct7': 0b0000000},
            'sll': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b001, 'funct7': 0b0000000},
            'srl': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b101, 'funct7': 0b0000000},
            'sra': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b101, 'funct7': 0b0100000},
            'slt': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b010, 'funct7': 0b0000000},
            'sltu': {'type': 'R', 'opcode': 0b0110011, 'funct3': 0b011, 'funct7': 0b0000000},
            
            # I-type instructions
            'addi': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b000},
            'andi': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b111},
            'ori':  {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b110},
            'xori': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b100},
            'slti': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b010},
            'sltiu': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b011},
            'slli': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b001, 'funct7': 0b0000000},
            'srli': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b101, 'funct7': 0b0000000},
            'srai': {'type': 'I', 'opcode': 0b0010011, 'funct3': 0b101, 'funct7': 0b0100000},
            'lb':   {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b000},
            'lh':   {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b001},
            'lw':   {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b010},
            'lbu':  {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b100},
            'lhu':  {'type': 'I', 'opcode': 0b0000011, 'funct3': 0b101},
            'jalr': {'type': 'I', 'opcode': 0b1100111, 'funct3': 0b000},
            
            # S-type instructions
            'sb': {'type': 'S', 'opcode': 0b0100011, 'funct3': 0b000},
            'sh': {'type': 'S', 'opcode': 0b0100011, 'funct3': 0b001},
            'sw': {'type': 'S', 'opcode': 0b0100011, 'funct3': 0b010},
            
            # B-type instructions
            'beq':  {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b000},
            'bne':  {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b001},
            'blt':  {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b100},
            'bge':  {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b101},
            'bltu': {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b110},
            'bgeu': {'type': 'B', 'opcode': 0b1100011, 'funct3': 0b111},
            
            # U-type instructions
            'lui':   {'type': 'U', 'opcode': 0b0110111},
            'auipc': {'type': 'U', 'opcode': 0b0010111},
            
            # J-type instructions
            'jal': {'type': 'J', 'opcode': 0b1101111},
        }
        
        # Register mapping (RISC-V style)
        self.registers = {
            'x0': 0, 'zero': 0,
            'x1': 1, 'ra': 1,
            'x2': 2, 'sp': 2,
            'x3': 3, 'gp': 3,
            'x4': 4, 'tp': 4,
            'x5': 5, 't0': 5,
            'x6': 6, 't1': 6,
            'x7': 7, 't2': 7,
            'x8': 8, 's0': 8, 'fp': 8,
            'x9': 9, 's1': 9,
            'x10': 10, 'a0': 10,
            'x11': 11, 'a1': 11,
            'x12': 12, 'a2': 12,
            'x13': 13, 'a3': 13,
            'x14': 14, 'a4': 14,
            'x15': 15, 'a5': 15,
            'x16': 16, 'a6': 16,
            'x17': 17, 'a7': 17,
            'x18': 18, 's2': 18,
            'x19': 19, 's3': 19,
            'x20': 20, 's4': 20,
            'x21': 21, 's5': 21,
            'x22': 22, 's6': 22,
            'x23': 23, 's7': 23,
            'x24': 24, 's8': 24,
            'x25': 25, 's9': 25,
            'x26': 26, 's10': 26,
            'x27': 27, 's11': 27,
            'x28': 28, 't3': 28,
            'x29': 29, 't4': 29,
            'x30': 30, 't5': 30,
            'x31': 31, 't6': 31
        }
        
        # Initialize symbol table for labels
        self.symbol_table = {}
        self.current_address = 0
        
    def parse_register(self, reg_str):
        """Convert register name to register number"""
        reg_str = reg_str.strip().lower()
        if reg_str in self.registers:
            return self.registers[reg_str]
        else:
            raise ValueError(f"Unknown register: {reg_str}")
    
    def parse_immediate(self, imm_str):
        """Parse immediate value from string"""
        imm_str = imm_str.strip()
        
        # Check if it's a symbol reference
        if imm_str in self.symbol_table:
            return self.symbol_table[imm_str]
        
        # Handle different number formats
        if imm_str.startswith('0x'):
            return int(imm_str, 16)
        elif imm_str.startswith('0b'):
            return int(imm_str, 2)
        else:
            return int(imm_str)
    
    def parse_memory_operand(self, mem_str):
        """Parse memory operand like '8(x5)' into offset and register"""
        pattern = r'(-?\d+)\(([a-zA-Z0-9]+)\)'
        match = re.match(pattern, mem_str.strip())
        if match:
            offset = int(match.group(1))
            reg = self.parse_register(match.group(2))
            return offset, reg
        else:
            raise ValueError(f"Invalid memory operand: {mem_str}")
    
    def is_directive(self, line):
        """Check if the line is an assembler directive"""
        directives = ['.text']
        line_parts = line.split()
        if line_parts and line_parts[0] in directives:
            return True
        return False
        
    def first_pass(self, lines):
        """First pass to collect all labels and their addresses"""
        address = 0
        for line in lines:
            # Remove comments and strip whitespace
            line = re.sub(r'#.*$', '', line).strip()
            if not line:
                continue
                
            # Skip assembler directives
            if self.is_directive(line):
                continue
                
            # Check if line contains a label
            label_match = re.match(r'^([a-zA-Z0-9_]+):', line)
            if label_match:
                label = label_match.group(1)
                self.symbol_table[label] = address
                
                # If line only contains a label, continue to next line
                remaining = line[label_match.end():].strip()
                if not remaining:
                    continue
                    
            # Every instruction is 4 bytes (32 bits)
            address += 4
    
    def assemble_r_type(self, opcode_info, operands):
        """Assemble R-type instruction"""
        if len(operands) != 3:
            raise ValueError(f"R-type instruction requires 3 operands, got {len(operands)}")
            
        rd = self.parse_register(operands[0])
        rs1 = self.parse_register(operands[1])
        rs2 = self.parse_register(operands[2])
        
        opcode = opcode_info['opcode']
        funct3 = opcode_info['funct3']
        funct7 = opcode_info['funct7']
        
        # Assemble the instruction: funct7 | rs2 | rs1 | funct3 | rd | opcode
        instruction = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
        return instruction
    
    def assemble_i_type(self, opcode_info, operands):
        """Assemble I-type instruction"""
        opcode = opcode_info['opcode']
        funct3 = opcode_info['funct3']
        
        # Handle load instructions separately
        if opcode_info['opcode'] == 0b0000011:  # LW
            if len(operands) != 2:
                raise ValueError(f"Load instruction requires 2 operands, got {len(operands)}")
                
            rd = self.parse_register(operands[0])
            offset, rs1 = self.parse_memory_operand(operands[1])
            
            # Ensure the immediate is within range and sign-extend
            if offset < -2048 or offset > 2047:
                raise ValueError(f"Immediate value {offset} is out of range for I-type instruction")
                
            imm = offset & 0xFFF  # 12-bit immediate
        
        # Handle JALR
        elif opcode_info['opcode'] == 0b1100111:  # JALR
            if len(operands) != 3:
                raise ValueError(f"JALR instruction requires 3 operands, got {len(operands)}")
                
            rd = self.parse_register(operands[0])
            rs1 = self.parse_register(operands[1])
            offset = self.parse_immediate(operands[2])
            
            if offset < -2048 or offset > 2047:
                raise ValueError(f"Immediate value {offset} is out of range for I-type instruction")
                
            imm = offset & 0xFFF  # 12-bit immediate
            
        # Regular I-type (addi, andi, etc.)
        else:
            if len(operands) != 3:
                raise ValueError(f"I-type instruction requires 3 operands, got {len(operands)}")
                
            rd = self.parse_register(operands[0])
            rs1 = self.parse_register(operands[1])
            imm = self.parse_immediate(operands[2])
            
            # Ensure the immediate is within range and sign-extend
            if imm < -2048 or imm > 2047:
                raise ValueError(f"Immediate value {imm} is out of range for I-type instruction")
                
            imm = imm & 0xFFF  # 12-bit immediate
            
        # Handle shift immediate instructions which include a funct7
        if opcode_info['opcode'] == 0b0010011 and funct3 in [0b001, 0b101]:
            # For slli, srli, srai
            funct7 = opcode_info.get('funct7', 0)
            # Shift amount is encoded in the lower 5 bits of the immediate
            shamt = imm & 0x1F
            # Immediate is funct7 (7 bits) concatenated with shamt (5 bits)
            imm = (funct7 << 5) | shamt
        
        # Assemble the instruction: imm[11:0] | rs1 | funct3 | rd | opcode
        instruction = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
        return instruction
    
    def assemble_s_type(self, opcode_info, operands):
        """Assemble S-type instruction (store)"""
        if len(operands) != 2:
            raise ValueError(f"S-type instruction requires 2 operands, got {len(operands)}")
            
        rs2 = self.parse_register(operands[0])
        offset, rs1 = self.parse_memory_operand(operands[1])
        
        opcode = opcode_info['opcode']
        funct3 = opcode_info['funct3']
        
        # Ensure the immediate is within range
        if offset < -2048 or offset > 2047:
            raise ValueError(f"Immediate value {offset} is out of range for S-type instruction")
            
        # Split immediate into two parts for S-type encoding
        imm_11_5 = (offset >> 5) & 0x7F  # Upper 7 bits
        imm_4_0 = offset & 0x1F          # Lower 5 bits
        
        # Assemble the instruction: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
        instruction = (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode
        return instruction
    
    def assemble_b_type(self, opcode_info, operands, current_address):
        """Assemble B-type instruction (branch)"""
        if len(operands) != 3:
            raise ValueError(f"B-type instruction requires 3 operands, got {len(operands)}")
            
        rs1 = self.parse_register(operands[0])
        rs2 = self.parse_register(operands[1])
        
        # Handle target label or immediate
        target = operands[2].strip()
        if target in self.symbol_table:
            # Calculate offset relative to current instruction
            offset = self.symbol_table[target] - current_address
        else:
            offset = self.parse_immediate(target)
        
        # Ensure offset is a multiple of 2 (half-word aligned)
        if offset % 2 != 0:
            raise ValueError(f"Branch offset {offset} must be a multiple of 2")
            
        # Ensure the offset is within range
        if offset < -4096 or offset > 4095:
            raise ValueError(f"Branch offset {offset} is out of range")
            
        # Extract the bits of the immediate in the order they appear in the instruction
        imm_12 = (offset >> 12) & 0x1     # bit 12
        imm_11 = (offset >> 11) & 0x1     # bit 11
        imm_10_5 = (offset >> 5) & 0x3F   # bits 10:5
        imm_4_1 = (offset >> 1) & 0xF     # bits 4:1
        
        opcode = opcode_info['opcode']
        funct3 = opcode_info['funct3']
        
        # Assemble the instruction: imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode
        instruction = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
                      (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode
        return instruction
    
    def assemble_u_type(self, opcode_info, operands):
        """Assemble U-type instruction (LUI, AUIPC)"""
        if len(operands) != 2:
            raise ValueError(f"U-type instruction requires 2 operands, got {len(operands)}")
            
        rd = self.parse_register(operands[0])
        imm = self.parse_immediate(operands[1])
        
        # U-type handles 20 bits of immediate, which are placed in the upper 20 bits of the 32-bit value
        imm_31_12 = (imm >> 12) & 0xFFFFF
        
        opcode = opcode_info['opcode']
        
        # Assemble the instruction: imm[31:12] | rd | opcode
        instruction = (imm_31_12 << 12) | (rd << 7) | opcode
        return instruction
    
    def assemble_j_type(self, opcode_info, operands, current_address):
        """Assemble J-type instruction (JAL)"""
        if len(operands) != 2:
            raise ValueError(f"J-type instruction requires 2 operands, got {len(operands)}")
            
        rd = self.parse_register(operands[0])
        
        # Handle target label or immediate
        target = operands[1].strip()
        if target in self.symbol_table:
            # Calculate offset relative to current instruction
            offset = self.symbol_table[target] - current_address
        else:
            offset = self.parse_immediate(target)
        
        # Ensure offset is a multiple of 2 (half-word aligned)
        if offset % 2 != 0:
            raise ValueError(f"Jump offset {offset} must be a multiple of 2")
            
        # Ensure the offset is within range
        if offset < -1048576 or offset > 1048575:
            raise ValueError(f"Jump offset {offset} is out of range")
            
        # Extract the bits of the immediate in the order they appear in the instruction
        imm_20 = (offset >> 20) & 0x1      # bit 20
        imm_10_1 = (offset >> 1) & 0x3FF   # bits 10:1
        imm_11 = (offset >> 11) & 0x1      # bit 11
        imm_19_12 = (offset >> 12) & 0xFF  # bits 19:12
        
        opcode = opcode_info['opcode']
        
        # Assemble the instruction: imm[20] | imm[10:1] | imm[11] | imm[19:12] | rd | opcode
        instruction = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | \
                      (imm_19_12 << 12) | (rd << 7) | opcode
        return instruction
    
    def assemble_instruction(self, line, address):
        """Assemble a single instruction line"""
        # Remove comments and strip whitespace
        line = re.sub(r'#.*$', '', line).strip()
        if not line:
            return None
            
        # Check for and remove label at the beginning of the line
        label_match = re.match(r'^([a-zA-Z0-9_]+):', line)
        if label_match:
            # Remove the label from the line
            line = line[label_match.end():].strip()
            if not line:  # If line only contains a label
                return None
        
        # Split instruction into opcode and operands
        parts = line.split()
        opcode_str = parts[0].lower()
        operands_str = " ".join(parts[1:])
        
        # Parse operands (comma-separated)
        operands = [op.strip() for op in operands_str.split(',')]
        
        # Get opcode information
        if opcode_str not in self.opcodes:
            raise ValueError(f"Unknown opcode: {opcode_str}")
            
        opcode_info = self.opcodes[opcode_str]
        
        # Assemble based on instruction type
        if opcode_info['type'] == 'R':
            return self.assemble_r_type(opcode_info, operands)
        elif opcode_info['type'] == 'I':
            return self.assemble_i_type(opcode_info, operands)
        elif opcode_info['type'] == 'S':
            return self.assemble_s_type(opcode_info, operands)
        elif opcode_info['type'] == 'B':
            return self.assemble_b_type(opcode_info, operands, address)
        elif opcode_info['type'] == 'U':
            return self.assemble_u_type(opcode_info, operands)
        elif opcode_info['type'] == 'J':
            return self.assemble_j_type(opcode_info, operands, address)
        else:
            raise ValueError(f"Unknown instruction type: {opcode_info['type']}")
    
    def assemble(self, assembly_code):
        """Assemble RISC assembly code to machine code"""
        lines = assembly_code.split('\n')
        
        # First pass to collect all labels
        self.first_pass(lines)
        
        # Second pass to assemble instructions
        machine_code = []
        address = 0
        
        for line in lines:
            # Remove comments and strip whitespace
            line = re.sub(r'#.*$', '', line).strip()
            if not line:
                continue
                
            # Skip assembler directives
            if self.is_directive(line):
                continue
                
            instruction = self.assemble_instruction(line, address)
            if instruction is not None:
                machine_code.append((address, instruction))
                address += 4
        
        return machine_code

def format_hex(num):
    """Format a number as a 32-bit hex string"""
    return f"0x{num:08x}"

def format_binary(num):
    """Format a number as a 32-bit binary string"""
    return f"0b{num:032b}"

def main():
    if len(sys.argv) < 2:
        print("Usage: python risc_assembler.py <input_file> [output_file]")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        with open(input_file, 'r') as f:
            assembly_code = f.read()
        
        assembler = RiscAssembler()
        machine_code = assembler.assemble(assembly_code)
        
        # Prepare output
        output_lines = []
        for address, instruction in machine_code:
            hex_instr = format_hex(instruction)
            bin_instr = format_binary(instruction)
            output_lines.append(f"{format_hex(address)}: {hex_instr} {bin_instr}")
        
        # Write output
        if output_file:
            with open(output_file, 'w') as f:
                for line in output_lines:
                    f.write(line + '\n')
                    
                # Also write a memory initialization format for simulation
                f.write("\n\n// Memory initialization format\n")
                for i, (_, instruction) in enumerate(machine_code):
                    f.write(f"instr_mem[{i}] = 32'h{instruction:08x};\n")
        else:
            for line in output_lines:
                print(line)
                
            # Also print memory initialization format
            print("\n\n// Memory initialization format")
            for i, (_, instruction) in enumerate(machine_code):
                print(f"instr_mem[{i}] = 32'h{instruction:08x};")
    
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 
