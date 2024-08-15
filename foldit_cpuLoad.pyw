#i want to add a 4th column in gui that shows the type based on the script name (text label from the foldit_log() function)

import psutil
import time
import os
import pygame
from collections import defaultdict, deque
import tkinter as tk
from tkinter import ttk, font
from pynput import keyboard
import threading
import re

import datetime
import subprocess
import ctypes
import shutil
import win32gui
import win32process
import win32con

# Initialize pygame for sound playback
pygame.mixer.init()
#pygame.mixer.music.load('alert_sound.mp3')  # Replace with your alert sound file path
pygame.mixer.music.load('Windows Print complete.wav')  # Replace with your alert sound file path

pressed = set()

COMBINATIONS = [
    {keyboard.Key.ctrl, keyboard.Key.page_down},
]

# Volume control (0.0 to 1.0)
VOLUME = 1
pygame.mixer.music.set_volume(VOLUME)
MAX_LINES = 400

# Parameters
CHECK_INTERVAL = 2  # seconds
MONITOR_DURATION = 60  # seconds
HIGH_CPU_THRESHOLD = 60  # percent
LOW_CPU_THRESHOLD = 15  # percent
FILENAME = 'Foldit.exe'


# Global exclusion array
EXCLUSION_CRITERIA = ["Group rank", "add any criteria to ignore the line that contains it when searching for score in recipe log file"]

# Process monitoring dictionary
monitored_processes = defaultdict(lambda: {'cpu_history': deque(maxlen=MONITOR_DURATION // CHECK_INTERVAL), 'high_cpu_count': 0, 'low_cpu_count': 0, 'low_cpu_start': None})

last_double_click_time = 0



def get_file_processes(filename):
    """Get all processes with the specified filename in their command line."""
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'exe']):
        try:
            if filename in proc.info['name']:
                processes.append(proc)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    return processes


def update_process_cpu_usage():
    """Update the CPU usage of processes and check thresholds."""
    global monitored_processes
    current_time = time.time()

    for proc in get_file_processes(FILENAME):
        pid = proc.pid
        try:
            cpu_usage = proc.cpu_percent(interval=None)
            monitored_processes[pid]['cpu_history'].append((current_time, cpu_usage))
            cpu_history_copy = list(monitored_processes[pid]['cpu_history'])
            if 'high_cpu_state' not in monitored_processes[pid]:
                monitored_processes[pid]['high_cpu_state'] = False
            high_cpu_count = sum(1 for _, usage in cpu_history_copy if usage > HIGH_CPU_THRESHOLD)
            if high_cpu_count / max(1, len(cpu_history_copy)) >= 0.90:
                monitored_processes[pid]['high_cpu_state'] = True
            low_cpu_count = sum(1 for _, usage in cpu_history_copy if usage < LOW_CPU_THRESHOLD)
            if low_cpu_count / max(1, len(cpu_history_copy)) >= 0.90:
                if monitored_processes[pid]['high_cpu_state']:
                    pygame.mixer.music.play()
                    monitored_processes[pid]['high_cpu_state'] = False
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            if pid in monitored_processes:
                del monitored_processes[pid]

def schedule_update():
    """Schedule the periodic update of the process list."""
    update_process_list()
    root.after(CHECK_INTERVAL * 1000, schedule_update)
    
def update_process_list():
    """Update the process list in the GUI."""
    global monitored_processes, folder_prefix
    #print (root.state())

    update_process_cpu_usage()
    processes = get_file_processes(FILENAME)
    processes.sort(key=lambda proc: natural_sort(os.path.basename(os.path.dirname(proc.exe()))))
    process_tree.delete(*process_tree.get_children())

    for proc in processes:
        try:
            pid = proc.pid
            cpu_history = monitored_processes[pid]['cpu_history']
            cpu_percent = sum(usage for _, usage in cpu_history) / len(cpu_history) if cpu_history else 0.0
            if cpu_percent < LOW_CPU_THRESHOLD:
                folder_prefix = "- "
            else:
                folder_prefix = ""
            folder = os.path.dirname(proc.exe())  # Store the full path
            folder_prefixed = folder_prefix + os.path.basename(folder)

            # Only calculate the highest score if the window is not withdrawn
            highest_score = None
            if root.state() != 'withdrawn':
                script_path = os.path.join(folder, "scriptlog.default.xml")
                script_type, highest_score = ReadFolditLogFile(script_path)
            else:
                score_display= ""
                highest_score = None
                script_type = ""
            
            # Format the score display based on the highest score (show one decimal in score). Not working with negative value
            if highest_score is not None:
                score_display = f"{str(highest_score).split('.')[0] + '.' + str(highest_score).split('.')[1][:1]}" if highest_score is not None else ""
            else: score_display= ""
            
            process_tree.insert('', 'end', values=(score_display, f"{cpu_percent:.0f}", folder_prefixed, script_type), tags=(int(pid), folder))
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
        
    adjust_column_widths(process_tree)
    adjust_window_size(process_tree, changeWidth = False)
    #root.after(CHECK_INTERVAL * 1000, update_process_list)

def natural_sort(value):
    """Function to perform a natural sort."""
    return [int(s) if s.isdigit() else s.lower() for s in re.split(r'(\d+)', value)]

def adjust_column_widths(treeview):
    """Adjust the column widths to fit their content."""
    for col in treeview['columns']:
        max_width = max(
            [treeview.heading(col)['text']] + 
            [treeview.set(child, col) for child in treeview.get_children()],
            key=len
        )
        treeview.column(col, width=tk.font.Font().measure(max_width) + 20)
def adjust_window_size(treeview, changeWidth = True):
    """Adjust the window size to fit the content of the Treeview."""
    total_width = sum(treeview.column(col, option='width') for col in treeview['columns'])
    row_height = 20  # Average height of one row
    num_rows = len(treeview.get_children())
    total_height = row_height * num_rows
    
    # Set a minimum height for the window
    min_height = 200
    min_width = 340
    
    # Update the window size
    window_width = max(min_width, root.winfo_width())  # Adding some padding
    #window_width = max(min_width, total_width + 20)  # Adding some padding
    window_height = max(min_height, total_height + 50)  # Adding some padding for headers
    
    root.geometry(f"{window_width}x{window_height}")

    
def make_window_draggable(window):
    """Make the window draggable by clicking anywhere on it."""
    def start_move(event):
        if time.time() - last_double_click_time > 1.5:  # Check if 1.5 seconds have passed since the last double click
            window.x = event.x
            window.y = event.y
    def do_move(event):
        if time.time() - last_double_click_time > 1.5:  # Check if 1.5 seconds have passed since the last double click
            deltax = event.x - window.x
            deltay = event.y - window.y
            window.geometry(f"+{window.winfo_x() + deltax}+{window.winfo_y() + deltay}")
    window.bind("<Button-1>", start_move)
    window.bind("<B1-Motion>", do_move)

def on_window_state_change(event):
    """Handle window state change events."""
    print("Window state changed:", root.state())
    #if root.state() in ['normal', 'iconic']:
    #update_process_list()
        
def on_key_press(key):
    global root
    pressed.add(key)
    if key == keyboard.Key.scroll_lock:
        if root.state() == 'normal':
            root.withdraw()
        else:
            root.deiconify()
            update_process_list()

def on_release(key):
    if key in pressed:
        #print ("released",key)
        pressed.remove(key)

def toggle_always_on_top():     
    global always_on_top
    always_on_top = not always_on_top
    root.attributes("-topmost", always_on_top)
    # Update the label of the first menu item (index 0)
    context_menu.entryconfig(0, label="Always on Top" if not always_on_top else "Remove Always on Top")

def show_context_menu(event):
    context_menu.post(event.x_root, event.y_root)


def activate_process_window(pid):
    def enum_windows_callback(hwnd, windows):
        if win32gui.IsWindowVisible(hwnd) and win32gui.IsWindowEnabled(hwnd):
            _, found_pid = win32process.GetWindowThreadProcessId(hwnd)
            windows.append((hwnd, found_pid, win32gui.GetWindowText(hwnd), win32gui.GetClassName(hwnd)))
    def get_process_windows(pid):
        windows = []
        win32gui.EnumWindows(enum_windows_callback, windows)
        return [(hwnd, title, class_name) for hwnd, found_pid, title, class_name in windows if found_pid == pid]

    
    windows = get_process_windows(int(pid))
    foldit_windows = [window for window in windows if 'Foldit' in window[1]]
    if not foldit_windows:
        print("No window with 'Foldit' in the title found.")
        return
    if len(foldit_windows) > 1:
        foldit_windows = [window for window in foldit_windows if window[2].lower() == 'foldit']

    if not foldit_windows:
        print("No unique window with 'Foldit' in the title and class name 'foldit' found.")
        return
    hwnd = foldit_windows[0][0]
    # Restore the window if it is minimized
    if win32gui.IsIconic(hwnd):
        win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
    win32gui.SetForegroundWindow(hwnd) # Bring the window to the front

def on_treeview_click(event):
    """Handle the event when an item in the treeview is double-clicked."""
    global last_double_click_time
    last_double_click_time = time.time()  # Record the current time
    column = process_tree.identify_column(event.x)  # identify the column
    item = process_tree.identify('item', event.x, event.y)  # identify the row
    pid, folder_path = process_tree.item(item, 'tags')  # Get the process ID and folder path from the item's tags
    if column == "#1" or column == "#4":
        foldit_log(folder_path)
    if column == "#2":
        print ("activating window", pid)
        activate_process_window(pid)
    if column == "#3":
        os.startfile(folder_path)  # opens folder for Windows only

def open_folder(folder_path):
    """Open the folder in the default file explorer."""
    try: os.system(f"open {folder_path}")  # This works on macOS
    except AttributeError:
        try: os.startfile(folder_path)  # This works on Windows
        except: os.system(f"xdg-open {folder_path}")  # This works on Linux

def foldit_log(folder_path):
    print ("Getting log from",folder_path)
    # Format time
    current_date = datetime.datetime.now().strftime("%Y%m%d")
    current_time = datetime.datetime.now().strftime("%H%M")
    clpbrd = f"{current_date}.{current_time}"

    script_path = os.path.join(folder_path, "scriptlog.default.xml")
    script_type, highest_score = ReadFolditLogFile(script_path)
    if highest_score:
        highest_score = int(highest_score)
    
    folder_name = os.path.basename(folder_path)
    folder_name_short = folder_name.replace ("oldit", "")
    clpbrd = os.path.join(folder_path, f"{folder_name_short}.{script_type}.{highest_score}.{clpbrd}..txt")
    shutil.copy(script_path, clpbrd)

    # Open the file with the default application
    subprocess.run(['start', clpbrd], shell=True)

    # Simulate sending {ctrl down}{end}{ctrl up}
    # This part is platform-dependent and may need a third-party library like pyautogui
    try:
        time.sleep(0.3)
        #def send_ctrl_end():
        ctypes.windll.user32.keybd_event(0xA2, 0, 0, 0)  # Ctrl down
        ctypes.windll.user32.keybd_event(0x23, 0, 0, 0)  # End down
        ctypes.windll.user32.keybd_event(0x23, 0, 2, 0)  # End up
        ctypes.windll.user32.keybd_event(0xA2, 0, 2, 0)  # Ctrl up
    except ImportError:
        print("error pressing the ctrl+end")

def ReadFolditLogFile(file_path):
    
    highest_score = None
    script_type = ""

    try:
        # Read the score file and script type file
        with open(file_path, 'r') as file:
            lines = file.readlines()

        # Determine the type based on the script name in the fourth line
        if len(lines) >= 4:
            script_name = lines[3].strip()  # Read the fourth line (index 3)
            if "quake" in script_name.lower():
                script_type = "Q4"
            elif "ideali" in script_name.lower():
                script_type += "Microidealize"
            elif "jet" in script_name.lower():
                script_type += "JET"
            elif "drw" in script_name.lower():
                script_type += "DRW"
            elif "remix" in script_name.lower():
                script_type += "Remix"
            elif "gab" in script_name.lower():
                script_type += "GAB"
            elif "helix" in script_name.lower():
                script_type += "Helix"
            elif "cut" in script_name.lower():
                script_type += "c-w"
            elif "worm" in script_name.lower():
                script_type += "Worm"
            elif "bwp" in script_name.lower():
                script_type += "bwp"
            elif "tweek" in script_name.lower():
                script_type += "Sidechain"
            elif "sidechain" in script_name.lower():
                script_type += "Sidechain"
            elif "prediction" in script_name.lower():
                script_type += "prediction"
            elif "rebuild" in script_name.lower():
                script_type += "Rebuild"
            elif "zz1" in script_name.lower():
                script_type += "Rebuild_loc"
            elif "defuze" in script_name.lower():
                script_type += "Defuze"
            elif "hinge" in script_name.lower():
                script_type += "Hinge"
            elif "ligand" in script_name.lower():
                script_type += "Ligand"
        #print (script_type, "script_type")

        # Patterns to match numbers with varying precision
        patterns = [
            re.compile(r'\b\d{4,5}\.\d+\b'),  # 4-5 digit numbers with any decimal places
            re.compile(r'\b\d{4,5}\b')        # 4-5 digit numbers with no decimal places
            #re.compile(r'\b\d{4,5}\.\d{2,}\b'),  # 4-5 digit numbers with 2+ decimal places
            #re.compile(r'\b\d{4,5}\.\d\b'),      # 4-5 digit numbers with 1 decimal place
            # re.compile(r'\b\d{4,5}\b')           # 4-5 digit numbers with no decimal places
        ]

        def process_lines(sub_lines):
            nonlocal highest_score
            for pattern in patterns:
                for line in reversed(sub_lines):
                    line_excluded = False
                    for exclusion in EXCLUSION_CRITERIA:
                        if exclusion in line:
                            line_excluded = True
                            break
                    if not line_excluded:
                        matches = pattern.findall(line)
                        for match in matches:
                            # Check for minus sign right before the number
                            match_start_index = line.find(match)
                            if match_start_index > 0 and line[match_start_index - 1] == '-':
                                continue
                            score = float(match)
                            if 1000 < score < 100000:
                                if highest_score is None or score > highest_score:
                                    highest_score = score
                if highest_score is not None:
                    return True
            return False
        
        # Ensure we are working with the last MAX_LINES lines if the file is too long
        if len(lines) > MAX_LINES:
            lines = lines[-MAX_LINES:]
        
        start_index = len(lines)
        score_mark = 1
        
        while start_index > 0 and highest_score is None:
            end_index = start_index
            start_index = max(0, end_index - MAX_LINES)
            sub_lines = lines[start_index:end_index]
            if process_lines(sub_lines):
                highest_score = highest_score * score_mark #show '-' if the score is too far away
                #print (score_mark, highest_score)
                break
            score_mark = -1


    except FileNotFoundError:
        print("no scriptlog.default.xml file found")

    return script_type, highest_score

        
def on_close():
    root.withdraw()
    return "break"

def close_app():
    root.destroy()

#--------------------------------------------------------------------------------------------
root = tk.Tk()
root.title("Process Monitor")
root.geometry("360x280")
make_window_draggable(root)

process_tree = ttk.Treeview(root, columns=("Score", "CPU", "Folder", "Type"), show="headings", selectmode='none')
process_tree.heading("Score", text="Score")
process_tree.heading("CPU", text="CPU")
process_tree.heading("Folder", text="Folder")
process_tree.heading("Type", text="Script")
process_tree.pack(fill="both", expand=True)

root.protocol("WM_DELETE_WINDOW", on_close)

# Create the context menu
context_menu = tk.Menu(root, tearoff=0)
context_menu.add_command(label="Always on Top", command=toggle_always_on_top)
context_menu.add_command(label="Close", command=close_app)
always_on_top = False

# Bind events for window state changes
#root.bind("<Unmap>", on_window_state_change)  # Minimized
root.bind("<Map>", on_window_state_change)    # Restored
# Bind right-click to show the context menu
root.bind("<Button-3>", show_context_menu)
# Bind the treeview click event to the on_treeview_click function
process_tree.bind('<Double-1>', on_treeview_click)

# Start the periodic update scheduling
schedule_update()

# Listen for hotkey to show/hide the window
hotkey_listener = keyboard.Listener(on_press=on_key_press, on_release=on_release)
hotkey_listener.start()

root.mainloop()
