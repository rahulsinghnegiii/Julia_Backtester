import os
import shutil
import tarfile
import subprocess
from googleapiclient.discovery import build
from google.oauth2 import service_account
from googleapiclient.http import MediaIoBaseDownload

# Request team lead to provide this file
json_key_path = 'drive-creds-algozen.json'

# Parent folder (one level above data) ID where the data will be stored
parent_drive_folder_id = "1r4dAMNuOj3GsRZoKto5KEj4fK4BQ_AWq"

def initialize_drive_service(json_key_path):
    """
    Initializes the Google Drive service using a JSON key file.

    Args:
        json_key_path (str): The path to the JSON key file.

    Returns:
        googleapiclient.discovery.Resource: The initialized Google Drive service.
    """
    creds = service_account.Credentials.from_service_account_file(
        json_key_path,
        scopes=['https://www.googleapis.com/auth/drive']
    )
    return build('drive', 'v3', credentials=creds)

def pull_and_decompress_data(drive_service, parent_drive_folder_id):
    """
    Pulls the latest compressed data file from Google Drive and decompresses it.

    Args:
        drive_service (googleapiclient.discovery.Resource): The Google Drive service.
        parent_drive_folder_id (str): The ID of the parent folder on Google Drive.
    """
    try:
        # Query for all files in the parent folder that are not trashed
        query = f"'{parent_drive_folder_id}' in parents and trashed=false"
        results = drive_service.files().list(q=query, orderBy="createdTime desc", fields="files(id, name, createdTime)").execute()
        all_files = results.get('files', [])

        # Filter files based on the naming pattern
        drive_files = [file for file in all_files if file['name'].endswith('_stock_data.tar')]

        if not drive_files:
            print("No compressed stock data files found on Google Drive.")
            return

        # Get the latest file
        latest_file = drive_files[0]
        file_id = latest_file['id']
        file_name = latest_file['name']

        # Download the latest file
        request = drive_service.files().get_media(fileId=file_id)
        file_path = file_name
        with open(file_path, 'wb') as f:
            downloader = MediaIoBaseDownload(f, request)
            done = False
            while not done:
                status, done = downloader.next_chunk()
                print(f"Download {int(status.progress() * 100)}%.")

        print(f"Downloaded latest file: {file_name}")

        # Decompress the downloaded file
        print("Decompressing file...")
        with tarfile.open("2024-09-02_stock_data.tar", mode='r') as tar:
            tar.extractall(path="")

        print(f"Successfully pulled and decompressed '{file_name}'")

        # Remove the compressed file
        # os.remove(file_path)
    except Exception as e:
        print(f"Error during pulling and decompressing data from server: {str(e)}")

def pull_db():
    """
    Pulls the database from Google Drive to the local 'data' folder.
    """
    try:
        drive_service = initialize_drive_service(json_key_path)
        pull_and_decompress_data(drive_service, parent_drive_folder_id)
    except Exception as e:
        print(f"Error during pulling DB from Drive: {str(e)}")

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

def copy_directory():
    try:
        print("Copying directory to destinations...")
        source = './data'
        destination = './App/data'
        copy_to_location(source, destination)
        print("Directory has been copied to all destinations")
    except Exception as e:
        print(f"Error copying directory to destinations: {str(e)}")


pull_db()
copy_directory()