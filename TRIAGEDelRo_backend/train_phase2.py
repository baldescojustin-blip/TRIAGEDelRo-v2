import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
import os
from PIL import ImageFile

# Tell the image library to ignore corrupted images instead of crashing
ImageFile.LOAD_TRUNCATED_IMAGES = True

def main():
    # 1. Standard image transformations for MobileNetV3
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])

    # 2. Load the datasets created by split_data.py
    train_dataset = datasets.ImageFolder('data/train', transform=transform)
    val_dataset = datasets.ImageFolder('data/validation', transform=transform)
    
    train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=32, shuffle=True)
    val_loader = torch.utils.data.DataLoader(val_dataset, batch_size=32, shuffle=False)

    # 3. Setup the MobileNetV3-Small model
    model = models.mobilenet_v3_small(pretrained=True)
    
    # Replace the final classification layer to output 4 classes
    model.classifier[3] = nn.Linear(model.classifier[3].in_features, 4)
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)

    # 4. Define loss function and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    print(f"Starting training on {device}...")
    best_acc = 0.0
    
    # 5. Training loop
    for epoch in range(5): 
        model.train()
        for inputs, labels in train_loader:
            inputs, labels = inputs.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

        # 6. Validation step
        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs, labels = inputs.to(device), labels.to(device)
                outputs = model(inputs)
                _, predicted = torch.max(outputs.data, 1)
                total += labels.size(0)
                correct += (predicted == labels).sum().item()

        acc = 100 * correct / total
        print(f"Epoch {epoch+1}/5 Validation Accuracy: {acc:.2f}%")
        
        # Save the model if it performs better than the previous epoch
        if acc > best_acc:
            best_acc = acc
            os.makedirs('phase2_training_output', exist_ok=True)
            torch.save(model.state_dict(), 'phase2_training_output/best_model.pt')
            print("Saved new best_model.pt")

if __name__ == '__main__':
    main()