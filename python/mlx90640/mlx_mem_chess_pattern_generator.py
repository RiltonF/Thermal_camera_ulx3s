#!/usr/bin/env python
# Simple subpage lookup table generator to determine which pixels needed updating


def chess_gen_odd():
    return [x%2 for x in range(32)]

def chess_gen_even():
    return [(x+1)%2 for x in range(32)]

def gen_page0():
    buff = []
    for _ in range (int(24/2)):
        buff.append(chess_gen_even())
        buff.append(chess_gen_odd())
    buff.append([1]*64) # we read 64 more words to get variables like Ta/VDD/GAIN
    return sum(buff, [])

def gen_page1():
    buff = []
    for _ in range (int(24/2)):
        buff.append(chess_gen_odd())
        buff.append(chess_gen_even())
    buff.append([1]*64) # we read 64 more words to get variables like Ta/VDD/GAIN
    return sum(buff, [])

if __name__ == "__main__":
    with open("mlx_subpage0_chess_pattern.mem", "w") as f:
        for val in gen_page0():
            f.write(f"{val}\n")

    with open("mlx_subpage1_chess_pattern.mem", "w") as f:
        for val in gen_page1():
            f.write(f"{val}\n")
