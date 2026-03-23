echo "============================================="
echo "  Автоматическая настройка сервера FastAPI   "
echo "============================================="

if ! command -v python3 &> /dev/null
then
    echo "Ошибка: Python 3 не установлен. Пожалуйста, установите его."
    exit 1
fi

echo "[1/4] Настройка виртуального окружения (venv)..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Виртуальное окружение создано."
fi


source venv/bin/activate

echo "[2/4] Установка необходимых библиотек..."
pip install --upgrade pip --quiet

# Если у вас есть файл requirements.txt, раскомментируйте следующую строку и удалите нижнюю:
pip install -r requirements.txt

echo ""
echo "[3/4] Настройка сетевого доступа..."
echo "Если вы хотите тестировать приложение с реального iPhone, сервер должен быть доступен в локальной сети."
read -p "Введите IP-адрес сервера (нажмите Enter для стандартного 0.0.0.0): " INPUT_IP
SERVER_IP=${INPUT_IP:-0.0.0.0}

read -p "Введите порт (нажмите Enter для стандартного 8000): " INPUT_PORT
SERVER_PORT=${INPUT_PORT:-8000}

echo ""
echo "[4/4] Запуск сервера на http://$SERVER_IP:$SERVER_PORT..."
echo "Для остановки сервера нажмите Ctrl+C"
echo "============================================="

python -m uvicorn main:app --host "$SERVER_IP" --port "$SERVER_PORT" --reload
