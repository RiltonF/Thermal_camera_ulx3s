def binary_file_to_hex(filename):
    with open(filename, 'r') as file:
        # Read all lines and join them into a single binary string
        binary_str = ''.join(line.strip() for line in file)

    # Remove any characters other than 0 and 1 (optional safeguard)
    binary_str = ''.join(c for c in binary_str if c in '01')

    # Pad the binary string to make its length a multiple of 4
    padding = (4 - len(binary_str) % 4) % 4
    binary_str = '0' * padding + binary_str

    # Convert binary string to hexadecimal
    hex_str = hex(int(binary_str, 2))[2:]  # [2:] removes the '0x' prefix

    return hex_str

# Example usage
file_path = './david_1bit.mem'  # Replace with your actual file path
hex_output = binary_file_to_hex(file_path)
print(f"Hex output:\n{hex_output}")
