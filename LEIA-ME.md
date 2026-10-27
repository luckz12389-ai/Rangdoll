# Ragdoll Sandbox (Fase 1) — APK pelo GitHub, sem Godot

1. Crie um repositório no GitHub (github.com > + > New repository).
2. Add file > Upload files: envie TODOS os arquivos desta pasta (sem pastas) e faça Commit.
3. Add file > Create new file. No nome digite: `.github/workflows/build.yml` e cole o conteúdo de `build.yml`. Commit.
4. Aba Actions: aguarde o build (5-10 min). Se não iniciar, abra "Build Android APK" > Run workflow.
5. Aba Releases (ou Actions > build > Artifacts): baixe `ragdoll-sandbox.apk` no celular e instale
   (permita "instalar apps desconhecidos").
Se o build falhar, abra o log do passo vermelho e me mande o texto do erro.
Controles: joystick à esquerda, arrastar à direita para olhar; botões PULAR, CORRER, NPC+, RUÍDO, KO, pausa, CÂM.
