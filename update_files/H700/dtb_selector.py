import os
import shutil
import sys
from wcwidth import wcswidth

# ==== 配置路径 ====
if getattr(sys, 'frozen', False):
    ROOT_DIR = os.path.dirname(sys.executable)
else:
    ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

DEVICE_TREES_DIR = os.path.join(ROOT_DIR, "device_trees")

# ==== 检查设备树目录是否存在 ====
if not os.path.isdir(DEVICE_TREES_DIR):
    print("[错误] 设备树目录丢失，请确认 device_trees 文件夹存在。")
    input("按任意键退出...")
    sys.exit(1)

# ==== 设备名与 dtb 映射表 ====
dtb_map = {
    "RG 28XX": "sun50i-h700-anbernic-rg28xx.dtb",
    "RG 35XXH": "sun50i-h700-anbernic-rg35xx-h.dtb",
    "RG 35XXH [新屏幕rev6]": "sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb",
    "RG 35XXPlus": "sun50i-h700-anbernic-rg35xx-plus.dtb",
    "RG 35XXPlus [新屏幕rev6]": "sun50i-h700-anbernic-rg35xx-plus-rev6-panel.dtb",
    "RG 35XX+": "sun50i-h700-anbernic-rg35xx-2024.dtb",
    "RG 35XX+ [新屏幕rev6]": "sun50i-h700-anbernic-rg35xx-2024-rev6-panel.dtb",
    "RG 35XX SP": "sun50i-h700-anbernic-rg35xx-sp.dtb",
    "RG 35XX SP [新屏幕V2]": "sun50i-h700-anbernic-rg35xx-sp-v2-panel.dtb",
    "RG 40XXH": "sun50i-h700-anbernic-rg40xx-h.dtb",
    "RG 40XXV": "sun50i-h700-anbernic-rg40xx-v.dtb",
    "RG CubeXX": "sun50i-h700-anbernic-rgcubexx.dtb",
    "RG 34XX": "sun50i-h700-anbernic-rg34xx.dtb",
    "RG 34XX SP": "sun50i-h700-anbernic-rg34xx-sp.dtb",
    "RG 35XX Pro": "sun50i-h700-anbernic-rg35xx-pro.dtb",
}

# ==== 显示菜单 ====
def show_menu():
    print("==============================")
    print("        请选择设备型号：")
    print("==============================")
    for i, name in enumerate(dtb_map.keys(), start=1):
        print(f" {i}. {name}")
    print("==============================")

def main():
    while True:
        os.system('cls' if os.name == 'nt' else 'clear')
        show_menu()
        choice = input("请输入编号（1-15）或输入 Q 退出：").strip()
        if choice.lower() == 'q':
            break
        if not choice.isdigit():
            input("无效输入，请输入数字编号。按回车继续...")
            continue

        index = int(choice)
        if index < 1 or index > len(dtb_map):
            input("编号超出范围，请重新选择。按回车继续...")
            continue

        name = list(dtb_map.keys())[index - 1]
        dtb_file = dtb_map[name]
        src = os.path.join(DEVICE_TREES_DIR, dtb_file)
        dst = os.path.join(ROOT_DIR, "dtb.img")

        if not os.path.exists(src):
            print(f"[错误] 未找到 DTB 文件：{src}")
            input("按回车退出...")
            break

        shutil.copyfile(src, dst)
        print(f"\n[完成] {name} 的设备树已成功复制为 dtb.img")
        input("按回车返回菜单...")

    print("\n感谢使用！")
    input("按任意键退出...")

if __name__ == '__main__':
    main()
    input("\n按下任意键退出...")
