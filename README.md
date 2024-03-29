# Open Camera    
 Open Camera é um plugin flutter, muito leve, agradável e intuitivo, que adiciona ao seu aplicativo a capacidade de tirar fotos e gravar vídeos.  
     
### Comece a usar 
É muito fácil utilizar o plugin o **Open Camera** em seu projeto, ele foi pensado para ser assim ;)

`Para sistemas Android a versão mínima do SDK é 24 e IOS versão mínima é 9.3.`

# Instalação 
A instalação do plugin na sua aplicação é muito simples, adicione no seu arquivo **pubspec.yaml** a referência do plugin **OpenCamera**.  
```
dependencies:
  open_camera:    
    git:
      url: 'https://github.com/openponce/opencamera.git'    
  flutter:    
    sdk: flutter  
```
    
### Android  
No arquivo **AndroidManifest.xml** adicione as seguintes permissões.  
```  
<uses-permission android:name="android.permission.INTERNET" /> 
<uses-permission android:name="android.permission.CAMERA" android:required="true" /> 
<uses-permission android:name="android.permission.RECORD_AUDIO" android:required="true" /> 
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:required="true" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:required="true" />  
```  
###  IOS  
No IOS é necessário editar os seguintes arquivos.  
  
**Arquivo PodFile**  
Altere a linha removendo o comentário e trocando a versão miníma no arquivo PodFile.

`O arquivo está na pasta ios/PodFile do seu projeto. ` 

```  
platform :ios, '9.3'  
```  
  
**Arquivo Info.plist**  
No arquivo **Info.plist** adicione as seguintes pemissões.  

`O arquivo está em ios/Runner/Info.plist no seu projeto.`
  
```
<key>NSCameraUsageDescription</key>
<string>Can I use the camera please?</string>    
<key>NSMicrophoneUsageDescription</key>
<string>Can I use the mic please?</string>    
<key>NSPhotoLibraryAddUsageDescription</key>    
<string>Camera App would like to save photos from the app to your gallery</string>    
<key>NSPhotoLibraryUsageDescription</key>    
<string>Camera App would like to access your photo gallery for uploading images to the app</string>    
<key>NSAppTransportSecurity</key>    
<dict>    
   <key>NSAllowsArbitraryLoads</key>    
   <true/>    
</dict>
```
# Como usar    

### Configurações

Configure de acordo com a necessidade ;)

```
var settings = CameraSettings(
  limitRecord: 15,
  useCompression: true,
  resolutionPreset: ResolutionPreset.ultraHigh,
  forceDeviceOrientation: true,
  deviceOrientation: [
    NativeDeviceOrientation.landscapeLeft,
    NativeDeviceOrientation.landscapeRight,
  ],
);

```

|Parâmetro| Tipo |Descrição|
|--|--|--|
|limitRecord| int |Tempo limite de gravação em segundos.|
|useCompression|bool|Se o plugin deve comprimir a foto ou vídeo antes de retornar|
|resolutionPreset|enum|Qualidade de resolução da câmera|
|forceDeviceOrientation|bool|Se o plugin deve restringir a orientação da câmera|
|deviceOrientation|array|Define quais orientações de câmera são permitidas pelo plugin|

### Tirando uma foto
```
File file = await openCamera(
  context,
  CameraMode.Photo,
  cameraSettings: CameraSettings(
    useCompression: true,
    resolutionPreset: ResolutionPreset.ultraHigh,
  ),
);

```
### Gravando um vídeo
```
File file = await openCamera(context,
                             CameraMode.Video,
                             cameraSettings: CameraSettings(
                                limitRecord: 15,
                                useCompression: true,
                                resolutionPreset: ResolutionPreset.ultraHigh,
                                forceDeviceOrientation: true,
                                deviceOrientation: [
                                  NativeDeviceOrientation.landscapeLeft,
                                  NativeDeviceOrientation.landscapeRight,
                                ],
                              ),
                            );
```

Autores.

Diogo Luiz Ponce (dlponce@gmail.com) / Joelson Santos Cunha (contato@joecorp.com.br)

