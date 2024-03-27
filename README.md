# Crater-Province-Level
A level meant to test and showcase Godot features and use cases for big and open worlds.

https://github.com/Jamsers/Crater-Province-Level/assets/39361911/06a0347a-3c72-4615-9bbf-f895daca5368

Featured:

- SDFGI  

- Dynamic time of day  
  Physically based lighting values  
  Dynamic (range) auto exposure  
  Seamless interior/exterior locations  

- Far sun shadows  
  Far volumetric fog  
  Far pointlights (à la GTA V lampposts)  
  
- GPU Instancing  
  Occlusion culling  
  Auto LOD  

Not featured:

- Asset streaming  
  World partitioning  

- Landscape system  
  Water system  
  Cloud system  
  Weather system  

Currently in active development, but development happens on a private Azure DevOps repo due to GitHub's 100 MB file limit. Updates will be pushed to this repo periodically.

## Time Of Day
Use the LightingChanger node to change time of day in editor.

![Screenshot 2024-03-27 165313](https://github.com/Jamsers/Crater-Province-Level/assets/39361911/f67893a3-b8e5-4ddb-9fd7-55573ed93ca2)

You can change time of day speed and pause time of day in the TimeOfDaySystem node.

![Screenshot 2024-03-27 165356](https://github.com/Jamsers/Crater-Province-Level/assets/39361911/d8a2724d-2283-4ed2-869b-0603e46f7066)

## Controls
- **ESCAPE** to capture/uncapture mouse  

- **W-A-S-D** to move  
  **SPACE** to jump  
  **TILDE(~)** to noclip  

## Credits

Uses IcterusGames' [SimpleGrassTextured](https://github.com/IcterusGames/SimpleGrassTextured) plugin.  
Uses Jamsers' [Godot-Human-For-Scale](https://github.com/Jamsers/Godot-Human-For-Scale).
