# Para instalar DataFramesMeta:
# using Pkg; Pkg.add("DataFramesMeta")

using JSON
using DataFrames
using DataFramesMeta # Recomendado para un filtrado más limpio

"""
Lee una variable de entorno que contiene un JSON, lo parsea 
y lo convierte en un DataFrame.
"""
function crear_df_desde_logs_env()::DataFrame
    logs_json_str = get(ENV, "LOGS_JSON_DATA", "")

    if isempty(logs_json_str)
        error("La variable de entorno 'LOGS_JSON_DATA' está vacía o no fue encontrada.")
    end

    try
        # JSON.parse puede devolver un vector de diccionarios, perfecto para DataFrame.
        logs_data = JSON.parse(logs_json_str)
        return DataFrame(logs_data)
    catch e
        println(stderr, "Error al parsear el JSON o crear el DataFrame: $e")
        rethrow() # Relanza la excepción para que Kestra marque la tarea como fallida.
    end
end

"""
Filtra un DataFrame de logs para devolver solo aquellos que tienen nivel 'ERROR'
y la palabra 'ERROR' en el mensaje.
"""
function filtrar_logs_de_error(logs_df::DataFrame)::DataFrame
    # Usando @subset de DataFramesMeta para un código más legible.
    # Esta es la forma moderna y recomendada.
    return @subset(logs_df, :level .== "ERROR", occursin.("ERROR", :message))
    
    # Alternativa con DataFrames base (lo que tenías, pero más compacto):
    # return logs_df[(logs_df.level .== "ERROR") .& occursin.("ERROR", logs_df.message), :]
end

function main()
    try
        # --- PASO 1: Procesar los datos UNA SOLA VEZ ---
        println("Procesando logs desde la variable de entorno...")
        logs_df = crear_df_desde_logs_env()
        
        # --- PASO 2: Mostrar los resultados ---
        println("\n-------- Mostrando todos los logs --------\n")
        if !isempty(logs_df)
            println(logs_df)
        else
            println("INFO: No se encontraron logs para mostrar.")
        end
        
        # --- PASO 3: Filtrar y mostrar los errores ---
        println("\n----------- Filtrando logs de error -----------")
        sleep(1) # Pausa cosmética si la necesitas
        
        df_errores = filtrar_logs_de_error(logs_df)
        
        println("\n-------- Mostrando solo logs de error --------\n")
        if !isempty(df_errores)
            println(df_errores)
        else
            println("INFO: No se encontraron logs con nivel 'ERROR'.")
        end
        
    catch e
        println(stderr, "Error crítico en la ejecución principal: $e")
        # Al usar rethrow() o dejar que la excepción se propague, 
        # el proceso terminará con un código de salida distinto de cero,
        # lo que Kestra interpretará como un fallo de la tarea.
        rethrow()
    end
end

# Ejecutar la función principal
main()