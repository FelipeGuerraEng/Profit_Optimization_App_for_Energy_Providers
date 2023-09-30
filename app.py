import streamlit as st
import pandas as pd
import minizinc

# Función para ejecutar el modelo MiniZinc
def ejecutar_modelo(archivo_dzn):
    # Crear un modelo MiniZinc
    model = minizinc.Model()
    model.add_file("PlantaEnergia.mzn")

    # Crear una instancia MiniZinc
    solver = minizinc.Solver.lookup("coin-bc")
    instance = minizinc.Instance(solver, model)

    # Leer los datos del archivo .dzn
    with open(archivo_dzn, "r") as file:
        data = file.read()
    instance.add_string(data)

    # Resolver la instancia
    result = instance.solve()

    return result

# Crear la interfaz de usuario con Streamlit
st.title("Optimización de la Ganancia Neta para Proveedores de Energía")


# Crear un formulario para ingresar los parámetros
with st.form("parametros"):
    n = st.number_input("Número de días", value=3, step=1, min_value=1)
    m = st.number_input("Número de clientes", value=3, step=1, min_value=1)
    if st.form_submit_button("Actualizar Clientes"):
        st.experimental_rerun()
        
    nombres_plantas = ['Central Nuclear', 'Central Hidroeléctrica', 'Central Térmica']
    capacidad_inicial = [1000, 300, 500]  # Los valores iniciales de la capacidad
    df = pd.DataFrame({
        'Planta': nombres_plantas,
        'Capacidad General (MW)': capacidad_inicial
    })
    df.index = df.index + 1
    st.table(df)
    dias_regimen_alto_permitidos = st.number_input("Días de régimen alto permitidos para la Central Hidroeléctrica", value=1, step=1, min_value=1)
    porcentaje_regimen_alto = st.number_input("Porcentaje de régimen alto para la Central Hidroeléctrica", value=80, step=1, min_value=1, max_value=100)
    G = st.number_input("Porcentaje mínimo de la demanda por cliente que debe ser satisfecha", value=50, step=1, min_value=1, max_value=100)
     
    # Capacidad de las plantas
    capacidad = st.text_input("Capacidad de las plantas en MW (separadas por comas: C.Nuclear, C.Hidroeléctrica, C.Térmica)", value="1000,300,500").split(',')
    capacidad = [int(c) for c in capacidad]

    # Costo de producción de las plantas
    costo_produccion = st.text_input("Costo de producción de las plantas por MW (separadas por comas: C.Nuclear, C.Hidroeléctrica, C.Térmica)", value="23,13,31").split(',')
    costo_produccion = [int(c) for c in costo_produccion]

    # Demanda de cada cliente por día
    demanda = []
    for i in range(m):
        demanda_cliente = st.text_input(f"Demanda del cliente {i+1} por día (separadas por comas: Día 1, Día 2,..., Día n)", value="61,149,104").split(',')
        demanda_cliente = [int(d) for d in demanda_cliente]
        demanda.append(demanda_cliente)
    
    # Pago por MW para cada cliente
    pago_por_mw = st.text_input("Pago por MW para cada cliente (separados por comas: Cliente 1, Cliente 2,..., Cliente n)", value="40,55,45").split(',')
    pago_por_mw = [int(p) for p in pago_por_mw]

    # Botón para ejecutar el modelo
    if st.form_submit_button("Ejecutar"):
        parametros = {
            "n": n,
            "m": m,
            "dias_regimen_alto_permitidos": dias_regimen_alto_permitidos,
            "porcentaje_regimen_alto": porcentaje_regimen_alto,
            "capacidad": capacidad,
            "costo_produccion": costo_produccion,
            "demanda": demanda,
            "pago_por_mw": pago_por_mw,
            "G": G
        }
        
         # Muestra los parámetros ingresados en una tabla
        #st.write("Parámetros ingresados:")
        #for key, value in parametros.items():
            #st.write(f"{key}: {value}")
        
         # Crear un archivo .dzn con los datos ingresados
        with open("Datos.dzn", "w") as file:
            for key, value in parametros.items():
                if isinstance(value, list):
                    if all(isinstance(i, list) for i in value):  # Para la matriz de demanda
                        file.write(f"{key} = [|\n")
                        for row in value:
                            file.write(', '.join(map(str, row)) + " |\n")
                        file.write("|];\n")
                    else:  # Para listas normales
                        file.write(f"{key} = [{', '.join(map(str, value))}];\n")
                else:  # Para valores individuales
                    file.write(f"{key} = {value};\n")

        # Ejecutar el modelo y mostrar los resultados
        resultado = ejecutar_modelo("Datos.dzn")
        #st.write(resultado)
        if resultado.status == minizinc.result.Status.OPTIMAL_SOLUTION:
            st.success("Se encontró una solución óptima.")
            st.success(f"Ganancia Neta: {resultado.solution.objective}")

            # Convertir los resultados en DataFrames y mostrarlos en tablas
            produccion_df = pd.DataFrame(resultado.solution.produccion, 
                                          columns=[f'Día {i+1}' for i in range(n)],
                                          index=[nombres_plantas[i] for i in range(len(capacidad))])

            st.write("Producción por planta por día:")
            st.table(produccion_df)

            entregado_df = pd.DataFrame(resultado.solution.entregado, 
                                         columns=[f'Día {i+1}' for i in range(n)],
                                         index=[f'Cliente {i+1}' for i in range(m)])
            st.write("Energía entregada a los clientes por día:")
            st.table(entregado_df)
        else:
            st.error("No se encontró una solución óptima.")
            st.error(f"Estado del resultado: {resultado.status}")
        
