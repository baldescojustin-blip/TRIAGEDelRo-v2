import os
import shutil
import random

def split_dataset(source_dir, dest_dir, split_ratio=0.8):
    # Updated to include all 4 of your folders
    classes = ['earthquake', 'fire', 'flood', 'landslide']
    
    for cls in classes:
        src_path = os.path.join(source_dir, cls)
        if not os.path.exists(src_path):
            print(f"Error: Could not find folder {src_path}. Did you put them inside {source_dir}?")
            continue
            
        images = os.listdir(src_path)
        random.shuffle(images)
        
        split_idx = int(len(images) * split_ratio)
        train_imgs = images[:split_idx]
        val_imgs = images[split_idx:]
        
        for folder_name, img_list in [('train', train_imgs), ('validation', val_imgs)]:
            dest_path = os.path.join(dest_dir, folder_name, cls)
            os.makedirs(dest_path, exist_ok=True)
            for img in img_list:
                shutil.copy(os.path.join(src_path, img), os.path.join(dest_path, img))
                
        print(f"Processed {cls}: {len(train_imgs)} train, {len(val_imgs)} validation.")

if __name__ == "__main__":
    split_dataset("raw_data", "data")