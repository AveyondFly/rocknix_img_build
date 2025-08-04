import os
import shutil
import sys
from wcwidth import wcswidth

# ==== 配置路径 ====
if getattr(sys, 'frozen', False):
    ROOT_DIR = os.path.dirname(sys.executable)
else:
    ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

CONFIG_DIR = os.path.join(ROOT_DIR, "config")  # 配置文件目录

# ==== 配置映射表 ====
dtb_map = {
    # V1
    "K36s": ("rk3326-gameconsole-k36s.dtb", None),
    "R36T": ("rk3326-gameconsole-r36t.dtb", None),    
    "U8": ("rk3326-gameconsole-u8.dtb", None),
    "HG36/HG3506": ("rk3326-gameconsole-hg36.dtb", None),
    # G80
    "R36S克隆 G80c v1.0": ("rk3326-r36s-clone-a.dtb", None),
    "R36S克隆 G80XF": ("rk3326-r36s-clone-b.dtb", None),
    "R36 Ultra": ("rk3326-gameconsole-r36u.dtb", None),
    #稀范科技
    "稀范科技 MyMini": ("rk3326-xifan-mymini.dtb", None),
    "稀范科技 XF35H": ("rk3326-xifan-xf35h.dtb", None),
    "稀范科技 R36Max": ("rk3326-xifan-r36max.dtb", None),
    "稀范科技 R36Pro": ("rk3326-xifan-r36pro.dtb", None),
    "稀范科技 XF40H": ("rk3326-xifan-xf40h.dtb", None),
    "稀范科技 XF40V": ("rk3326-xifan-xf40v.dtb", None),
    # 安伯尼克
    "安伯尼克 RG351M": ("rk3326-anbernic-rg351m.dtb", None),
    "安伯尼克 RG351V": ("rk3326-anbernic-rg351v.dtb", None),
    "安伯尼克 RG351V V2屏幕": ("rk3326-anbernic-rg351v.dtb", "overlays-rg351v-p2"),
    "安伯尼克 RG351MP": ("rk3326-gameconsole-r36s.dtb", "overlays-rg351mp-p2"),
    # GameConsole
    "GameConsole R33s": ("rk3326-gameconsole-r33s.dtb", None),
    "GameConsole R36s P1屏幕": ("rk3326-gameconsole-r33s.dtb", None),
    "GameConsole R36s P2屏幕": ("rk3326-gameconsole-r33s.dtb", "overlays-r36s-p2"),
    "GameConsole R36s P3屏幕": ("rk3326-gameconsole-r33s.dtb", "overlays-r36s-p3"),
    "GameConsole R36s P4屏幕": ("rk3326-gameconsole-r36s-v4.dtb", None),
    "GameConsole R36xx": ("rk3326-gameconsole-r36xx.dtb", None),
    "GameConsole R36sPlus": ("rk3326-gameconsole-r36plus.dtb", None),
    # Magicx
    "Magicx Xu10": ("rk3326-magicx-xu10.dtb", None),
    "Magicx Xu Mini M": ("rk3326-magicx-xu-mini-m.dtb", None),
    # 泡机堂
    "泡机堂 RGB10": ("rk3326-powkiddy-rgb10.dtb", None),
    "泡机堂 RGB10X": ("rk3326-powkiddy-rgb10x.dtb", None),
    "泡机堂 RGB2OS": ("rk3326-powkiddy-rgb20s.dtb", None),
    # GAMEMT
    "GAMEMT E6": ("rk3326-gamemt-e6.dtb", None),
    # Odroid
    "Odroid Go2": ("rk3326-odroid-go2.dtb", None),
    "Odroid Go2 v11屏幕": ("rk3326-odroid-go2-v11.dtb", None),
    "Odroid Go3": ("rk3326-odroid-go3.dtb", None)
}

def wpad(text, width):
    pad = width - wcswidth(text)
    return text + ' ' * max(pad, 0)

def center_text(text, width):
    pad_total = width - wcswidth(text)
    return ' ' * (pad_total // 2) + text

def print_colored_line(text, width=80):
    BLUE_BG = '\033[44m'
    WHITE_TEXT = '\033[97m'
    RESET = '\033[0m'
    print(f"{BLUE_BG}{WHITE_TEXT}{wpad(text, width)}{RESET}")

def show_menu():
    terminal_width = shutil.get_terminal_size((80, 20)).columns
    border = '█' * terminal_width
    separator = '─' * terminal_width
    
    print_colored_line(border, terminal_width)
    print_colored_line(center_text('RK3326 启动配置切换工具', terminal_width), terminal_width)
    print_colored_line("📌 操作说明：", terminal_width)
    print_colored_line("   - 自动删除旧 boot.ini 和 overlays 文件夹", terminal_width)
    print_colored_line("   - 从 config 目录读取模板生成配置文件", terminal_width)
    print_colored_line("   - R36H、O30s等P4屏幕的机器选择R36s P4屏幕", terminal_width)
    print_colored_line("   - 泡机堂V10 请选择 泡机堂10", terminal_width)
    print_colored_line(border, terminal_width)
    
    print(separator)
    print("请选择配置：")
    

    keys = list(dtb_map.keys())
    per_line = 2
    col_width = terminal_width // per_line
    
    for i, name in enumerate(keys, 1):
        entry = f"{str(i).rjust(2)}. {name}"
        print(wpad(entry, col_width), end='')
        if i % per_line == 0:
            print()
    
    if len(keys) % per_line != 0:
        print()
    
    print_colored_line(border, terminal_width)
    return keys

def get_user_choice(keys):
    while True:
        try:
            choice = int(input("输入编号：").strip())
            if 1 <= choice <= len(keys):
                return keys[choice - 1]
            print("编号超出范围，请重新输入。")
        except ValueError:
            print("请输入有效数字。")

def clean_old_files():
    print("\n清理旧配置文件...")
    boot_ini = os.path.join(ROOT_DIR, "boot.ini")
    if os.path.exists(boot_ini):
        os.remove(boot_ini)
        print(f"已删除: boot.ini")
    
    overlays_dir = os.path.join(ROOT_DIR, "overlays")
    if os.path.exists(overlays_dir):
        shutil.rmtree(overlays_dir)
        print(f"已删除: overlays 文件夹")

def setup_config(dtb_file, overlay_dir=None):
    """设置新配置"""
    # 检查config目录是否存在
    if not os.path.exists(CONFIG_DIR):
        print(f"错误: 找不到config目录 {CONFIG_DIR}")
        return False

    # 生成 boot.ini
    template_name = "boot-overlays.ini" if overlay_dir else "boot.ini"
    template_path = os.path.join(CONFIG_DIR, template_name)
    
    try:
        # 读取模板文件
        with open(template_path, "r", encoding="utf-8") as f:
            content = f.read().replace("my.dtb", dtb_file)
        
        # 写入新文件，强制使用LF换行符
        with open(os.path.join(ROOT_DIR, "boot.ini"), "w", encoding="utf-8", newline='\n') as f:
            f.write(content)
        print(f"已生成: boot.ini (使用 {dtb_file})")
    except FileNotFoundError:
        print(f"错误: 找不到模板文件 {template_path}")
        return False

    # 复制 overlays (如果有)
    if overlay_dir:
        source_overlay = os.path.join(CONFIG_DIR, overlay_dir)
        target_overlay = os.path.join(ROOT_DIR, "overlays")
        
        try:
            if os.path.exists(source_overlay):
                shutil.copytree(source_overlay, target_overlay)
                print(f"已复制: {overlay_dir} → overlays")
            else:
                print(f"错误: 找不到 overlays 文件夹 {source_overlay}")
                return False
        except Exception as e:
            print(f"复制overlays失败: {str(e)}")
            return False
    
    return True


def main():
    readme = os.path.join(ROOT_DIR, "Mac User Please Readme.txt")
    if os.path.exists(readme):
        os.remove(readme)
    keys = show_menu()
    selected = get_user_choice(keys)
    dtb_file, overlay_dir = dtb_map[selected]
    
    print(f"\n正在设置: {selected}")
    print(f"使用DTB: {dtb_file}")
    if overlay_dir:
        print(f"使用Overlays: {overlay_dir}")
    
    clean_old_files()
    if setup_config(dtb_file, overlay_dir):
        print("\n配置完成!")
    else:
        print("\n配置过程中出现错误，请检查文件是否存在")
    
    input("\n按回车键退出...")

if __name__ == "__main__":
    main()