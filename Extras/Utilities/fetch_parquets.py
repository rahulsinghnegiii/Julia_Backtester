import subprocess
import shutil
import os

def run_command(command):
    """
    Runs a shell command and returns the output
    """
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, stderr = process.communicate()
    
    if process.returncode != 0:
        raise Exception(f"Command failed with error: {stderr.decode('utf-8')}")
    
    return stdout.decode('utf-8')

def pull_from_drive(remote_name, local_folder_path, remote_folder_path):
    try:
        command = f"rclone copy {remote_name}:{remote_folder_path} {local_folder_path} --progress"
        print(f"Pulling folder: {remote_folder_path} to {local_folder_path}")
        run_command(command)
        print("Pull completed.")
    except Exception as e:
        print(f"Error during pulling folder from server: {str(e)}")

def copy_to_location(source, destination):
    print(f"Copying directory {source} to {destination}")

    # Check if the destination directory exists
    if os.path.exists(destination):
        # Remove the existing destination directory and its contents
        shutil.rmtree(destination)
    
    # Ensure the destination parent directory exists
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    
    # Copy the entire directory tree
    shutil.copytree(source, destination)
    
    print(f"Directory {source} has been copied to {destination}")

def pull_db():
    try:
        remote_name = 'dev_drive'
        local_folder_path = '../data'
        remote_folder_path = 'system_backup/stock_db_backup/data'
        pull_from_drive(remote_name, local_folder_path, remote_folder_path)
    except Exception as e:
        print(f"Error during pulling DB from server: {str(e)}")

def copy_directory():
    try:
        print("Copying directory to destinations...")
        source = '../data'
        destination = '../../data'
        copy_to_location(source, destination)
        print("Directory has been copied to all destinations")
    except Exception as e:
        print(f"Error copying directory to destinations: {str(e)}")

pull_db()
copy_directory()