# ArAppCalHacks
## Inspiration
Want to take advantage of the AR and object detection technologies to help people to gain safer walking experiences and communicate distance information to help people with visual loss navigate.

## What it does
Augment the world with the beeping sounds that change depending on your proximity towards obstacles and identifying surrounding objects and convert to speech to alert the user.

## How we built it
ARKit; RealityKit uses Lidar sensor to detect the distance; AVFoundation, text to speech technology; CoreML with YoloV3 real time object detection machine learning model; SwiftUI

## Challenges we ran into
Computational efficiency. Going through all pixels in the LiDAR sensor in real time wasn’t feasible. We had to optimize by cropping sensor data to the center of the screen

## Accomplishments that we're proud of
It works as intended.

## What we learned
We learned how to combine AR, AI, LiDar, ARKit and SwiftUI to make an iOS app in 15 hours.

## What's next for SeerAR
Expand to Apple watch and Android devices; Improve the accuracy of object detection and recognition; Connect with Firebase and Google cloud APIs;

## Built With
arkit
avfoundation
swiftui
yolov3

## Downdload and Try it out!

YoloV3 AI model: https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3/YOLOv3.mlmodel
Could not be uploaded to github because size is too big
