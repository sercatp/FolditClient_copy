import os
import shutil
import tkinter as tk
from tkinter import messagebox

def copy_latest_subdir(src_folder, dest_folder):
    # Get list of subdirectories sorted by modification time
    subdirs = sorted((os.path.join(src_folder, d) for d in os.listdir(src_folder) if os.path.isdir(os.path.join(src_folder, d))), key=os.path.getmtime, reverse=True)
    
    if not subdirs:
        messagebox.showerror("Error", f"No subdirectories found in {src_folder}")
        return
    
    latest_subdir = subdirs[0]
    dest_path = os.path.join(dest_folder, os.path.basename(latest_subdir))

    # If destination directory already exists, delete it
    if os.path.exists(dest_path):
        shutil.rmtree(dest_path)

    # Copy latest subdir to destination
    shutil.copytree(latest_subdir, dest_path)
    messagebox.showinfo("Success", f"Copied {latest_subdir} to {dest_path}")
    window.destroy()

def on_first_entry_key(event):
    if len(src_entry.get()) >= 1:
        if not event.keysym.isdigit():  # Check if the entered key is a digit
            src_entry.delete(0, tk.END)  # Clear the entry field if it's not a digit
        dest_entry.focus_set()

def on_copy_button_click(event=None):
    src_folder_input = src_entry.get()
    dest_folder_input = dest_entry.get()

    src_folder = f"C:\\Games\\Foldit{src_folder_input}\\puzzles\\"
    dest_folder = f"C:\\Games\\Foldit{dest_folder_input}\\puzzles\\"

    # Check if source and destination folders exist
    if not os.path.exists(src_folder):
        messagebox.showerror("Error", f"Source folder does not exist: {src_folder}")
    elif not os.path.exists(dest_folder):
        messagebox.showerror("Error", f"Destination folder does not exist: {dest_folder}")
    else:
        copy_latest_subdir(src_folder, dest_folder)

# Create main window
window = tk.Tk()
window.title("Copy Latest Subdirectory")

# Source folder input
src_label = tk.Label(window, text="Source Folder Number:")
src_label.grid(row=0, column=0, padx=5, pady=5)
src_var = tk.StringVar()
src_var.trace_add("write", lambda name, index, mode, sv=src_var: on_src_entry_change())
src_entry = tk.Entry(window, textvariable=src_var, width=5)
src_entry.grid(row=0, column=1, padx=5, pady=5)
src_entry.focus_set()  # Set focus on this entry

# Destination folder input
dest_label = tk.Label(window, text="Destination Folder Number:")
dest_label.grid(row=1, column=0, padx=5, pady=5)
dest_entry = tk.Entry(window, width=5)
dest_entry.grid(row=1, column=1, padx=5, pady=5)

def on_src_entry_change():
    if len(src_entry.get()) == 1:
        dest_entry.focus_set()

# Copy button
copy_button = tk.Button(window, text="Copy Latest Subdirectory", command=on_copy_button_click)
copy_button.grid(row=2, column=0, columnspan=2, padx=5, pady=5)

# Bind <Return> event to on_copy_button_click
window.bind('<Return>', on_copy_button_click)

# Run the main event loop
window.mainloop()
