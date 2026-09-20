import io
from flask import Flask, jsonify, request
import torch
from torchvision import models, transforms
from PIL import Image
import urllib.request

app = Flask(__name__)

model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
model.eval()

labels_url = "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
class_names = urllib.request.urlopen(labels_url).read().decode('utf-8').splitlines()

transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])


@app.route('/predict', methods=['POST'])
def predict():
    if 'img' not in request.files:
        return jsonify({'error': 'No se envio ninguna imagen (campo "img")'}), 400

    img_file = request.files['img']
    img = Image.open(io.BytesIO(img_file.read())).convert('RGB')
    img_tensor = transform(img).unsqueeze(0)

    with torch.no_grad():
        output = model(img_tensor)
        probs = torch.nn.functional.softmax(output[0], dim=0)
        top_prob, top_idx = torch.max(probs, 0)

    prediction = ('The input picture is classified as [%s], with probability %.3f.' %
                  (class_names[top_idx.item()], top_prob.item()))

    return jsonify({'prediction': prediction})


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
