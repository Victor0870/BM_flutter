import telebot
import os
import shutil
import subprocess
import pyautogui
import psutil
import time
import sys
import tempfile
import threading
from PIL import Image

# --- 1. CẤU HÌNH CỦA BẠN ---
API_TOKEN = '8506704093:AAEXWl0pgLoqe2CCwBD2YJb162IB5MgFs58'
AUTHORIZED_CHAT_ID = 2048321442  # ID lấy từ @userinfobot

# Đường dẫn tới Cursor Agent CLI (chỉ cần set nếu 'agent' không có trong PATH)
# Cách 1: Cài CLI rồi thêm vào PATH — mở PowerShell chạy: irm 'https://cursor.com/install?win32=true' | iex
# Cách 2: Set biến môi trường CURSOR_AGENT_PATH (ví dụ: C:\Users\You\.cursor\bin\agent.exe)
# Cách 3: Gán trực tiếp dưới đây, ví dụ: AGENT_CMD = r'C:\Users\Admin\AppData\Local\Programs\cursor\agent.exe'
AGENT_CMD = os.environ.get('CURSOR_AGENT_PATH', '').strip() or None

# True = khi gọi /codepos, /codegame, /codeweb sẽ mở luôn Cursor IDE (app) với thư mục dự án
OPEN_CURSOR_IDE = True

# "ide" = chỉ mở Cursor IDE + copy prompt vào clipboard (dán vào Composer trong Cursor), không mở Agent CLI
# "cli" = mở Cursor IDE + chạy Agent trong cửa sổ PowerShell (như hiện tại)
CODE_MODE = "ide"

# Thời gian chờ (giây) cho Cursor lên/focus trước khi click + dán (chế độ "ide")
IDE_FOCUS_DELAY = 2.5
# Click chuột tại (x, y) trước khi Ctrl+V. Lệnh thường: /codepos, /codegame... dùng tọa độ này.
IDE_CLICK_BEFORE_PASTE = (1188, 952)
# Lệnh có hậu tố N (vd /codeposN): click tại đây rồi dán. None = không click khi dùng N.
IDE_CLICK_BEFORE_PASTE_N = (1845, 46)
# Đường dẫn file APK release (dùng lệnh /apk để gửi vào Telegram)
APK_PATH = r"D:\Flutter\bizmate_app\build\app\outputs\flutter-apk\app-release.apk"
# Thư mục Google Drive (Desktop): copy APK vào đây để sync lên Drive. Để rỗng "" thì lệnh /apkdrive không dùng.
# VD: r"C:\Users\Admin\Google Drive\My Drive\APK" hoặc r"G:\My Drive\APK"
GOOGLE_DRIVE_APK_FOLDER = r"G:\My Drive\Apk"

# --- 2. DANH MỤC CÁC DỰ ÁN (Thay đổi đường dẫn thực tế của bạn) ---
PROJECTS = {
    'pos': r"D:\Flutter\bizmate_app",        # Dự án Flutter POS
    'app': r"D:\Flutter\Maintain_app",
    'game': r"D:\Unity\Savage Beasts 3",                     # Dự án Unity Game
    'web': r"D:\Flutter\bizmate_web"                         # Dự án Web
}

bot = telebot.TeleBot(API_TOKEN)
# Tăng timeout khi gửi file lớn (APK ~44MB) để tránh TimeoutError write operation
try:
    import telebot.apihelper as apihelper
    apihelper.READ_TIMEOUT = 300
    apihelper.WRITE_TIMEOUT = 300
except (AttributeError, ImportError):
    pass


def _get_agent_executable():
    """Tìm đường dẫn chạy Cursor Agent CLI (Windows thường không có 'agent' trong PATH)."""
    if AGENT_CMD and os.path.isfile(AGENT_CMD):
        return AGENT_CMD
    # Thử các vị trí cài đặt thường gặp trên Windows
    user = os.environ.get('USERPROFILE', '')
    local = os.environ.get('LOCALAPPDATA', '')
    candidates = [
        os.path.join(user, '.cursor', 'bin', 'agent.exe'),
        os.path.join(user, '.cursor', 'bin', 'agent.cmd'),
        os.path.join(local, 'cursor', 'agent.exe'),
        os.path.join(local, 'Programs', 'cursor', 'agent.exe'),
        os.path.join(local, 'cursor', 'bin', 'agent.exe'),
    ]
    for p in candidates:
        if p and os.path.isfile(p):
            return p
    # Nếu đã cài CLI và PATH có 'agent' (terminal mới sau khi cài), dùng 'agent'
    return 'agent'


def _get_cursor_ide_path():
    """Tìm Cursor IDE (app) trên Windows để mở thư mục dự án."""
    if sys.platform != 'win32':
        return None
    local = os.environ.get('LOCALAPPDATA', '')
    candidates = [
        os.path.join(local, 'Programs', 'cursor', 'Cursor.exe'),
        os.path.join(local, 'cursor', 'Cursor.exe'),
    ]
    for p in candidates:
        if p and os.path.isfile(p):
            return p
    return None


def _open_cursor_ide(workspace_path: str) -> None:
    """Mở Cursor IDE với thư mục dự án (để bạn thấy app Cursor bật lên / focus)."""
    exe = _get_cursor_ide_path()
    if exe and os.path.isdir(workspace_path):
        subprocess.Popen([exe, workspace_path], shell=False)


def _copy_to_clipboard(text: str) -> bool:
    """Copy text vào clipboard (Windows: dùng PowerShell)."""
    if sys.platform != 'win32':
        return False
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8') as f:
            f.write(text)
            tmp = f.name
        subprocess.run(
            ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
             f'Set-Clipboard -Value (Get-Content -Path \"{tmp}\" -Raw -Encoding UTF8)'],
            capture_output=True,
            timeout=5,
        )
        if tmp:
            os.unlink(tmp)
        return True
    except Exception:
        if tmp and os.path.isfile(tmp):
            try:
                os.unlink(tmp)
            except Exception:
                pass
        return False


def _ide_paste_after_delay(use_n_click: bool = False) -> None:
    """Chờ Cursor focus, click tại tọa độ (N hoặc thường), dán (Ctrl+V), Enter. Không dùng Ctrl+N."""
    time.sleep(IDE_FOCUS_DELAY)
    try:
        if use_n_click and IDE_CLICK_BEFORE_PASTE_N:
            x, y = IDE_CLICK_BEFORE_PASTE_N
            pyautogui.click(x, y)
        elif IDE_CLICK_BEFORE_PASTE:
            x, y = IDE_CLICK_BEFORE_PASTE
            pyautogui.click(x, y)
        time.sleep(0.25)
        pyautogui.hotkey('ctrl', 'v')
        time.sleep(0.3)
        pyautogui.press('enter')
    except Exception:
        pass


def _run_agent(prompt: str, workspace_path: str, use_n_click: bool = False) -> None:
    """Chạy Cursor Agent với prompt và workspace. use_n_click=True khi lệnh có hậu tố N (vd /codeposN)."""
    # Chế độ "ide": mở Cursor IDE + copy prompt + sau vài giây click tọa độ rồi dán (không Ctrl+N)
    if CODE_MODE == "ide":
        _open_cursor_ide(workspace_path)
        _copy_to_clipboard(prompt)
        threading.Thread(target=_ide_paste_after_delay, kwargs={"use_n_click": use_n_click}, daemon=True).start()
        return
    # Chế độ "cli": mở Cursor IDE (nếu bật) rồi chạy Agent trong PowerShell
    if OPEN_CURSOR_IDE:
        _open_cursor_ide(workspace_path)
    exe = _get_agent_executable()
    if exe and exe != 'agent' and os.path.isfile(exe):
        subprocess.Popen(
            [exe, prompt, '--workspace', workspace_path],
            shell=False,
            creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == 'win32' else 0,
        )
        return
    # Trên Windows: gọi qua PowerShell, dùng -NoExit để cửa sổ không đóng (xem được lỗi / agent chạy)
    if sys.platform == 'win32':
        prompt_esc = prompt.replace("'", "''")
        path_esc = workspace_path.replace("'", "''")
        cmd = f"agent '{prompt_esc}' --workspace '{path_esc}'"
        subprocess.Popen(
            ['powershell', '-ExecutionPolicy', 'Bypass', '-NoProfile', '-NoExit', '-Command', cmd],
            creationflags=subprocess.CREATE_NEW_CONSOLE,
        )
        return
    subprocess.Popen(f'agent "{prompt}" --workspace "{workspace_path}"', shell=True)


# Middleware: Bảo mật chỉ cho phép bạn điều khiển
@bot.message_handler(func=lambda message: message.chat.id == AUTHORIZED_CHAT_ID)
def handle_commands(message):
    text = message.text
    cmd_parts = text.split(' ', 1)
    full_command = cmd_parts[0].lower()

    # --- LỆNH ĐIỀU KHIỂN ĐA DỰ ÁN (/codepos, /codeposN, /codegame, ...) ---
    if full_command.startswith('/code'):
        raw_key = full_command.replace('/code', '')
        use_n_click = raw_key.endswith('n')
        project_key = raw_key[:-1] if use_n_click else raw_key

        if project_key in PROJECTS:
            if len(cmd_parts) < 2:
                bot.reply_to(message, f"⚠️ Thiếu yêu cầu. VD: /{full_command} Sửa màu nút")
                return
            
            path = PROJECTS[project_key]
            prompt = cmd_parts[1]
            
            bot.reply_to(message, f"🤖 [DỰ ÁN: {project_key.upper()}]\n🚀 Đang gọi Cursor Agent tại: {path}\n📝 Yêu cầu: {prompt}")
            
            try:
                _run_agent(prompt, path, use_n_click=use_n_click)
                if CODE_MODE == "ide":
                    click_note = "click (vị trí N) rồi dán + gửi" if use_n_click else "click rồi dán + gửi"
                    bot.send_message(AUTHORIZED_CHAT_ID,
                        f"✅ Đã mở Cursor + copy prompt.\n⏱ Sau ~{int(IDE_FOCUS_DELAY)}s sẽ {click_note} – giữ cửa sổ Cursor active.")
                else:
                    bot.send_message(AUTHORIZED_CHAT_ID, f"✅ Đã kích hoạt Agent cho {project_key.upper()}!")
            except FileNotFoundError:
                bot.reply_to(message, "❌ Không tìm thấy Cursor Agent CLI.\n"
                             "Cài đặt: mở PowerShell chạy: irm 'https://cursor.com/install?win32=true' | iex\n"
                             "Hoặc set biến môi trường CURSOR_AGENT_PATH = đường dẫn tới agent.exe")
            except Exception as e:
                bot.reply_to(message, f"❌ Lỗi: {str(e)}")
        else:
            bot.reply_to(message, f"❌ Không thấy dự Kong dự án '{project_key}'.\nDùng /list để xem danh sách.")

    # --- LỆNH DANH SÁCH DỰ ÁN ---
    elif full_command == '/list':
        list_text = "📁 Danh sách dự án đang quản lý:\n"
        for key in PROJECTS:
            list_text += f"🔹 {key} (/{key})\n"
        bot.reply_to(message, list_text)

    # --- LỆNH GỬI APK VÀO TELEGRAM ---
    elif full_command == '/apk':
        if os.path.isfile(APK_PATH):
            bot.reply_to(message, "⏳ Đang gửi APK (file ~44MB, có thể mất 1–2 phút)...")
            try:
                with open(APK_PATH, 'rb') as f:
                    bot.send_document(AUTHORIZED_CHAT_ID, f, caption="📦 app-release.apk", timeout=300)
                bot.send_message(AUTHORIZED_CHAT_ID, "✅ Đã gửi APK vào chat.")
            except Exception as e:
                bot.reply_to(message, f"❌ Gửi lỗi: {str(e)}")
        else:
            bot.reply_to(message, f"❌ Không tìm thấy file APK.\nĐường dẫn: {APK_PATH}")

    # --- LỆNH COPY APK SANG GOOGLE DRIVE (Desktop) ---
    elif full_command == '/apkdrive':
        if not GOOGLE_DRIVE_APK_FOLDER or not GOOGLE_DRIVE_APK_FOLDER.strip():
            bot.reply_to(message, "❌ Chưa cấu hình GOOGLE_DRIVE_APK_FOLDER trong Nova_ai.py.")
            return
        if not os.path.isfile(APK_PATH):
            bot.reply_to(message, f"❌ Không tìm thấy file APK.\n{APK_PATH}")
            return
        dest_dir = GOOGLE_DRIVE_APK_FOLDER.strip()
        try:
            os.makedirs(dest_dir, exist_ok=True)
            dest_file = os.path.join(dest_dir, "app-release.apk")
            if os.path.isfile(dest_file):
                os.remove(dest_file)  # Xóa file cũ để copy đè (overwrite)
            shutil.copy2(APK_PATH, dest_file)
            bot.reply_to(message, f"✅ Đã copy APK vào Google Drive (đè file cũ nếu có).\n📁 {dest_file}\n(Sync lên Drive tự động nếu đã bật Google Drive Desktop.)")
        except Exception as e:
            bot.reply_to(message, f"❌ Lỗi copy: {str(e)}")

    # --- LỆNH CHỤP MÀN HÌNH (Để xem AI đang làm gì) ---
    elif full_command == '/screen':
        screenshot = pyautogui.screenshot()
        screenshot.save("current_view.png")
        with open("current_view.png", "rb") as photo:
            bot.send_photo(AUTHORIZED_CHAT_ID, photo, caption="📸 Màn hình Desktop hiện tại")

    # --- LỆNH KIỂM TRA SỨC KHỎE MÁY (CPU/RAM) ---
    elif full_command == '/status':
        cpu = psutil.cpu_percent()
        ram = psutil.virtual_memory().percent
        bot.reply_to(message, f"📊 Hệ thống:\n🔥 CPU: {cpu}%\n🧠 RAM: {ram}%")

    # --- LỆNH TẮT MÁY TỪ XA ---
    elif full_command == '/shutdown':
        bot.reply_to(message, "💤 Đang tắt máy tính...")
        os.system("shutdown /s /t 5")

    else:
        bot.reply_to(message, "❓ Lệnh không rõ. Hãy dùng:\n/codepos, /codegame, /list, /apk, /apkdrive, /screen, /status")

# Kiểm tra / thông báo Agent CLI khi chạy trên Windows
if sys.platform == 'win32':
    exe = _get_agent_executable()
    if exe and exe != 'agent' and os.path.isfile(exe):
        print(f"✓ Cursor Agent: {exe}")
    else:
        print("✓ Cursor Agent: sẽ gọi qua PowerShell khi dùng /codepos, /codegame, /codeweb")

# Polling với tự kết nối lại khi mất mạng / ReadTimeout (tránh sập Bot)
print("🚀 TRẠM ĐIỀU KHIỂN ĐA DỰ ÁN ĐANG CHẠY...")
while True:
    try:
        bot.polling(non_stop=True, interval=0, timeout=60)
    except Exception as e:
        print(f"⚠️ Cảnh báo: Mất kết nối Telegram ({e})")
        print("🔄 Đang kết nối lại sau 15 giây...")
        time.sleep(15)