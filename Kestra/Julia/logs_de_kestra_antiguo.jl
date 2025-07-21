using JSON
using DataFrames


function logs_to_df()::DataFrame
    try
        logs_json_kestra = get(ENV, "LOGS_JSON_DATA", "")

        if isempty(logs_json_kestra)
            println(stderr, "Error, no hay datos de logs.")
            error("La variable de entorno 'LOGS_JSON_DATA' está vacía o no fue encontrada.")
        end
        logs_en_JSON = JSON.parse(logs_json_kestra)
        logs_df = DataFrame(logs_en_JSON)
        return logs_df
        
    catch e
        println(stderr, "Error inesperado al procesar los logs: $e")
        rethrow()
    end
end



function mostrar_df(df_de_kestra::DataFrame)
    try
        if !isempty(df_de_kestra)
            println(df_de_kestra)
        else
            println(stderr, "Error: El DataFrame a mostrar está vacío.") 
            error("DataFrame vacío para mostrar.")
        end
    catch e
        println(stderr, "Error inesperado al intentar mostrar el DataFrame: $e")
        rethrow()
    end
end



function mostrar_logs_de_error(df_kestra_original::DataFrame)
    try
        if !isempty(df_kestra_original)
            df_errors_level = df_kestra_original.level .== "ERROR"
            df_errors_message = occursin.("ERROR", df_kestra_original.message)
            df_level_and_message = df_kestra_original[df_errors_level .& df_errors_message, :]
            return df_level_and_message
        else
            return DataFrame()
        end 
    catch e
        println(stderr, "Error inesperado al filtrar logs de error: $e")
        rethrow()
    end
    
end

function main()
    
    try
        resultado_completo = mostrar_df(logs_to_df()) # <-- Una vez aquí
        resultado_level_message = mostrar_logs_de_error(logs_to_df()) # <-- ¡Mal! ¿OTRA VEZ?
        
        println("--------Mostrando logs--------")
        sleep(1)
        println(resultado_completo)
        println("-----------Filtrando----------")
        sleep(3)
        println(resultado_level_message)
        
    catch e
        println(stderr, "Error en la función principal al mostrar/filtrar logs: $e")
        rethrow()
    end
end

main()