import serial

ser = serial.Serial('/dev/ttyUSB0', 115200)

def to_signed(bits, n):
    if n >= 2**(bits - 1):
        n -= 2**bits
    return n

def dump_pretty(open_file, ugly_list):
    open_file.write("[")
    for i in range(0, len(ugly_list), 32):
        chunk = ugly_list[i:i+32]
        line = ", ".join(str(v) for v in chunk)
        # Don't add newline on the last chunk
        if i + 32 >= len(ugly_list):
            open_file.write(f"{line}")
        else:
            open_file.write(f"{line},\n")
    open_file.write("]\n")

def get_dump(ser, frames):
    count = 0;
    in_sync = False
    payload = False
    payload_data = []
    payload_hex = []
    payload_signed = []
    frame_hex = []
    frame_signed = []
    dump_count = 0
    with open("dump_hex.log", "w") as hex_file, open("dump_signed.log", "w") as signed_file:
        while True:
            mask = 0b1111_1111_1110_1000
            pattern = 0b0000_0000_0000_1000

            if not in_sync:
                byte = ser.read(1)[0]
                if byte == 0x00:
                    # Possible MSB detected
                    next_byte = ser.read(1)[0]
                    word = (byte << 8) | next_byte
                    # if word in [0x0008,0x0009]:
                    if word in [0x0008]:
                        # print(f"[SYNCED] {word:#06x}")
                        hex_file.write(f"[SYNCED]New data for subpage #{word%2}: {word:#06x}?\n")
                        signed_file.write(f"[SYNCED]New data for subpage #{word%2}: {word:#06x}?\n")
                        in_sync = True
                        count = 0
                        payload = True
                        paylaod_dat = []
                    else:
                        continue
                else:
                    # Not in sync yet, discard
                    continue
            else: 
                msb = ser.read(1)[0]
                lsb = ser.read(1)[0]
                word = (msb << 8 | lsb)

                if not payload:
                    # if (word & mask) == pattern:
                    if (word & mask) in [0x0008,0x0009]:
                        print(f"New data for subpage #{word%2}: {word:#06x}?")
                        count = 0
                        payload = True
                        hex_file.write(f"New data for subpage #{word%2}: {word:#06x}?\n")
                        signed_file.write(f"New data for subpage #{word%2}: {word:#06x}?\n")
                    else:
                        print(f"unknown: {word:#06x}?")
                else:
                    count += 1
                    # print(f"{count} - {word:#06x}")
                    # print(f"{word:#06x}")
                    payload_data.append(word)
                    payload_hex.append(hex(word))
                    payload_signed.append(to_signed(16, word))

                    # hex_file.write(f"{hex(word)}\n")
                    # signed_file.write(f"{to_signed(16, word)}\n")

                    if(count == 32*24+64):
                        # hex_file.write(str(payload_hex) + "\n")
                        # signed_file.write(str(payload_signed) + "\n")
                        payload = False
                        # print(payload_data)
                        # print(payload_signed)
                        print(payload_hex)
                        dump_pretty(hex_file,payload_hex)
                        dump_pretty(signed_file,payload_signed)
                        dump_count += 1
                        frame_signed.append(payload_signed[:-64])
                        frame_hex.append(payload_hex[:-64])
                        payload_hex = []
                        payload_signed = []


                        if (dump_count >= (frames * 2)):
                            print(f"Done with dumping {dump_count // 2} frames")
                            # return payload_signed[:-64] # drop the last 64 elements as they are not pixel data
                            return frame_signed
                        else:
                            continue

if __name__ == "__main__":
    get_dump(ser, 4)
