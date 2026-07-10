@echo off
python tests\run_project_tests.py
if errorlevel 1 (
	pause
	exit /b 1
)
rojo serve default.project.json
pause
