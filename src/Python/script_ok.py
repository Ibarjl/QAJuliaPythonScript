# script_ok.py
import os

def saludar(nombre):
    """Retorna un saludo."""
    print(f"Hola desde Python, {nombre}!")
    return f"Saludo enviado a {nombre}"

def sumar(a, b):
    """Suma dos números."""
    return a + b

def obtener_ruta_actual():
    """Retorna la ruta absoluta del directorio actual."""
    return os.getcwd()