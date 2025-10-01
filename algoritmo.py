import serial
import numpy as np
import time
import matplotlib.pyplot as plt
from scipy.signal import butter, filtfilt
from scipy.integrate import cumulative_trapezoid

### 🔹 CONFIGURAÇÃO DA PORTA SERIAL 🔹 ###
PORTA_SERIAL = "COM7"  # Altere conforme necessário
BAUD_RATE = 115200
IMPACTO_LIMITE = 5.0  # Limiar de impacto (m/s²)

# Conectar à Serial
ser = serial.Serial(PORTA_SERIAL, BAUD_RATE, timeout=2)
time.sleep(2)  # Tempo para estabilizar a conexão

### 🔹 FUNÇÕES DE PROCESSAMENTO 🔹 ###
def lowpass_filter(data, cutoff=50, fs=500, order=3):
    nyquist = 0.5 * fs
    normal_cutoff = cutoff / nyquist
    b, a = butter(order, normal_cutoff, btype='low', analog=False)
    return filtfilt(b, a, data)

def calculate_magnitude(ax, ay, az, gx, gy, gz):
    a_total = np.sqrt(ax**2 + ay**2 + az**2)  # Em m/s²
    omega_total = np.sqrt(gx**2 + gy**2 + gz**2)  # Em °/s
    return a_total, omega_total

def calculate_hic(time, acceleration):
    hic_values = []
    for i in range(len(time)):
        for j in range(i+1, len(time)):
            dt = time[j] - time[i]
            if 0.015 <= dt <= 0.036:  # Janela de 15 a 36ms
                integral = cumulative_trapezoid(acceleration[i:j], time[i:j], initial=0)
                avg_acc = integral[-1] / dt
                hic = (avg_acc ** 2.5) * dt
                hic_values.append(hic)
    return max(hic_values) if hic_values else 0

def calculate_bric(omega_max, t_crit=66):
    return omega_max / t_crit

def classify_impact(hic, bric):
    if hic < 250 and bric < 1.0:
        return "🔵 Baixo Risco"
    elif 250 <= hic <= 1000 or 1.0 <= bric <= 2.0:
        return "🟠 Risco Moderado"
    else:
        return "🔴 Alto Risco"

### 🔹 FUNÇÃO PRINCIPAL PARA MONITORAMENTO 🔹 ###
plt.ion()  # Modo interativo do Matplotlib
fig, Ax = plt.subplots(2, 1, figsize=(12, 8))

while True:
    ax_list = [] 
    ay_list = [] 
    az_list = []
    gx_list = [] 
    gy_list = []
    gz_list = []
    time_list = []

    print("\nAguardando impacto...")

    while True:
        linha = ser.readline().strip().decode("iso-8859-1")
        print(linha)
        if linha:
            dados = linha.split(",")
            if len(dados) >= 6:
                ax = float(dados[0])
                ay = float(dados[1])
                az = float(dados[2])
                gx = float(dados[3])
                gy = float(dados[4])
                gz = float(dados[5])
                tempo = time.time()

                # Cálculo da aceleração total
                a_total = np.sqrt(ax**2 + ay**2 + az**2)

                # Se detectou impacto, começa a coletar dados
                if a_total > IMPACTO_LIMITE:
                    print("⚠️ IMPACTO DETECTADO!")
                    break  # Sai do loop e começa a registrar dados

    start_time = time.time()
    while len(time_list) < 100:  # Coletar 100 amostras (~1 segundo)
        linha = ser.readline().decode().strip()
        if linha:
            try:
                dados = linha.split(",")
                if len(dados) >= 6:
                    ax_list.append(float(dados[0]))
                    ay_list.append(float(dados[1]))
                    az_list.append(float(dados[2]))
                    gx_list.append(float(dados[3]))
                    gy_list.append(float(dados[4]))
                    gz_list.append(float(dados[5]))
                    time_list.append(time.time() - start_time)
            except (ValueError, IndexError):
                continue

    # Converter listas para arrays numpy
    ax_list, ay_list, az_list = np.array(ax_list), np.array(ay_list), np.array(az_list)
    gx_list, gy_list, gz_list = np.array(gx_list), np.array(gy_list), np.array(gz_list)
    time_list = np.array(time_list)

    # Aplicar filtro
    ax_list = lowpass_filter(ax_list)
    ay_list = lowpass_filter(ay_list)
    az_list = lowpass_filter(az_list)
    gx_list = lowpass_filter(gx_list)
    gy_list = lowpass_filter(gy_list)
    gz_list = lowpass_filter(gz_list)

    # Calcular aceleração total e rotação total
    acc_total, omega_total = calculate_magnitude(ax_list, ay_list, az_list, gx_list, gy_list, gz_list)

    # Calcular HIC e BRIC
    hic_value = calculate_hic(time_list, acc_total)
    bric_value = calculate_bric(max(omega_total))

    # Classificação do impacto
    impact_severity = classify_impact(hic_value, bric_value)

    ### 🔹 ATUALIZAÇÃO DOS GRÁFICOS 🔹 ###
    Ax[0].cla()
    Ax[1].cla()

    # Subplot para aceleração
    Ax[0].plot(time_list, acc_total, label="Aceleração Total (m/s²)", color="blue")
    Ax[0].axhline(y=50, color='green', linestyle='--', label="Limite Baixo")
    Ax[0].axhline(y=100, color='red', linestyle='--', label="Limite Alto")
    Ax[0].set_xlabel("Tempo (s)")
    Ax[0].set_ylabel("Aceleração (m/s²)")
    Ax[0].set_title("Aceleração Total")
    Ax[0].legend()
    
    # Subplot para rotação
    Ax[1].plot(time_list, omega_total, label="Velocidade Angular (°/s)", color="orange")
    Ax[1].set_xlabel("Tempo (s)")
    Ax[1].set_ylabel("Velocidade Angular (°/s)")
    Ax[1].set_title("Velocidade Angular Total")
    Ax[1].legend()
    
    # Exibir HIC e BRIC no gráfico
    text_str = f"HIC: {hic_value:.2f}\nBRIC: {bric_value:.2f}\n{impact_severity}"
    fig.text(0.7, 0.75, text_str, fontsize=14, bbox=dict(facecolor='white', alpha=0.8))

    # Atualizar gráfico
    plt.draw()
    plt.pause(0.1)
