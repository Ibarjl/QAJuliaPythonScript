# script_error.py

def causar_error(data):
    """Intencionalmente causa un error para demostrar el manejo de excepciones."""
    if data == "dato_malo":
        raise ValueError("Se detectó un dato inválido: " + str(data))
    return "No hubo error con: " + str(data)

def dividir(a, b):
    """Intenta dividir, pero puede causar un error de división por cero."""
    return a / b