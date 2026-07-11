#!/bin/bash
# Script de build para a Vercel

echo "Clonando Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

echo "Habilitando e compilando para Web..."
./flutter/bin/flutter config --enable-web
./flutter/bin/flutter build web --release
