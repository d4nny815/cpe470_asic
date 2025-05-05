H_VISIBLE_AREA = 800
V_VISIBLE_AREA = 600

with open("../rtl/pixel_row.mem", "w") as f:
    for i in range(V_VISIBLE_AREA):
        value = i * H_VISIBLE_AREA
        f.write(f"{value:05x}\n")  # hex, zero-padded if needed
