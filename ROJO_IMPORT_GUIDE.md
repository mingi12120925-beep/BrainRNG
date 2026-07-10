# Brain RNG Rojo Import Guide

이 폴더는 Brain RNG Simulator의 Roblox Script를 로컬 파일로 관리하기 위한 Rojo 스캐폴드입니다.

## 중요 안전 규칙

- 원본 Roblox place를 먼저 `.rbxl` 또는 `.rbxlx`로 백업하세요.
- 처음 Rojo 연결은 반드시 테스트용 복사본 place에서만 진행하세요.
- 아직 Studio Script 원문이 로컬 파일로 복사되지 않았으므로, 바로 Rojo Connect를 누르지 마세요.
- 빈 `.lua` 파일을 만들면 Studio 내부 Script를 빈 내용으로 덮어쓸 수 있으므로 만들지 않았습니다.
- Workspace 맵, 파트, 모델은 이번 단계에서 Rojo로 관리하지 않습니다.

## Studio에서 복사해야 할 파일

아래 Script Source를 Studio에서 열어 각각 대응 파일로 저장하세요.

### ServerScriptService

- `ServerScriptService.GameServer` -> `src/ServerScriptService/GameServer.server.lua`
- `ServerScriptService.GameLogic` -> `src/ServerScriptService/GameLogic.lua`
- `ServerScriptService.DataManager` -> `src/ServerScriptService/DataManager.lua`
- `ServerScriptService.ConceptGenerator` -> `src/ServerScriptService/ConceptGenerator.lua`
- `ServerScriptService.SimpleWorldBuilder` -> `src/ServerScriptService/SimpleWorldBuilder.lua`

### StarterPlayerScripts

- `StarterPlayer.StarterPlayerScripts.UIController` -> `src/StarterPlayer/StarterPlayerScripts/UIController.client.lua`

## Remotes

`ReplicatedStorage.Remotes` 폴더는 Rojo 프로젝트에 포함되어 있습니다.
기존 RemoteEvent 이름은 바꾸지 마세요.

필수 RemoteEvent:

- `RollRequest`
- `UpgradeRequest`
- `AutoRollUpgradeRequest`
- `AdminTestRequest`
- `UpdateStats`
- `PopupEvent`

RemoteEvent 인스턴스는 `GameServer.lua`의 getOrCreate 로직으로도 보장됩니다.

## Rojo 실행

Rojo CLI 설치 후 이 폴더에서 실행하세요.

```powershell
cd C:\Users\최준태\Documents\Codex\BrainRNG
rojo serve
```

Roblox Studio에서는 Rojo Plugin에서 `localhost:34872`에 Connect하세요.

## 연결 전 체크리스트

- 테스트용 place인지 확인
- 위 6개 Lua 파일이 모두 실제 Studio Source 내용으로 채워졌는지 확인
- `GameServer.server.lua`가 빈 파일이 아닌지 확인
- `UIController.client.lua`가 빈 파일이 아닌지 확인
- 복구용 일회성 Script는 Disabled 또는 삭제 상태인지 확인

## 연결 후 확인할 Explorer 구조

- `ServerScriptService/GameServer`
- `ServerScriptService/GameLogic`
- `ServerScriptService/DataManager`
- `ServerScriptService/ConceptGenerator`
- `ServerScriptService/SimpleWorldBuilder`
- `StarterPlayer/StarterPlayerScripts/UIController`
- `ReplicatedStorage/Remotes`

