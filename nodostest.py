import cv2
import networkx as nx
import matplotlib.pyplot as plt
import tkinter as tk
from tkinter import filedialog, simpledialog
import numpy as np
import pickle

# Crear la ventana principal
root = tk.Tk()
root.title("Editor de Mapa - Definir Nodos y Caminos")

# Variables globales
graph = nx.Graph()
nodes = {}
map_image = None
image_path = ""
selected_nodes = []

# Función para cargar una imagen
def load_image():
    global map_image, image_path
    image_path = filedialog.askopenfilename(filetypes=[("Imágenes", "*.png;*.jpg;*.jpeg")])
    if image_path:
        map_image = cv2.imread(image_path)
        cv2.imshow("Mapa Cargado - Haz clic para agregar nodos", map_image)
        cv2.setMouseCallback("Mapa Cargado - Haz clic para agregar nodos", add_node)

# Función para agregar nodos con clic en la imagen
def add_node(event, x, y, flags, param):
    if event == cv2.EVENT_LBUTTONDOWN:
        node_name = f"Nodo_{len(nodes)+1}"
        nodes[node_name] = (x, y)
        graph.add_node(node_name, pos=(x, y))
        print(f"Nodo agregado: {node_name} en {x}, {y}")
        draw_graph()

# Función para conectar nodos con clic
def select_nodes(event, x, y, flags, param):
    if event == cv2.EVENT_LBUTTONDOWN:
        closest_node = min(nodes, key=lambda n: np.linalg.norm(np.array(nodes[n]) - np.array([x, y])))
        selected_nodes.append(closest_node)
        print(f"Seleccionado: {closest_node}")
        
        if len(selected_nodes) == 2:
            node1, node2 = selected_nodes
            distance = np.linalg.norm(np.array(nodes[node1]) - np.array(nodes[node2]))
            graph.add_edge(node1, node2, weight=distance)
            print(f"Conexión agregada: {node1} <-> {node2} con distancia {distance}")
            selected_nodes.clear()
            draw_graph()

# Función para guardar el grafo en un archivo
def save_graph():
    file_path = filedialog.asksaveasfilename(defaultextension=".pkl", filetypes=[("Grafo", "*.pkl")])
    if file_path:
        with open(file_path, "wb") as f:
            pickle.dump((nodes, graph), f)
        print("Grafo guardado correctamente.")

# Función para cargar un grafo desde un archivo
def load_graph():
    global nodes, graph
    file_path = filedialog.askopenfilename(filetypes=[("Grafo", "*.pkl")])
    if file_path:
        with open(file_path, "rb") as f:
            nodes, graph = pickle.load(f)
        print("Grafo cargado correctamente.")
        draw_graph()

# Función para calcular la mejor ruta con A*
def calculate_route():
    start_node = simpledialog.askstring("Ruta", "Ingrese el nodo de inicio:")
    end_node = simpledialog.askstring("Ruta", "Ingrese el nodo de destino:")
    if start_node in nodes and end_node in nodes:
        try:
            path = nx.astar_path(graph, start_node, end_node, weight="weight")
            print(f"Ruta calculada: {path}")
            draw_graph(path)
        except nx.NetworkXNoPath:
            print("No hay una ruta válida entre los nodos seleccionados.")
    else:
        print("Uno o ambos nodos no existen")

# Función para dibujar el grafo sobre el mapa
def draw_graph(path=None):
    if map_image is None:
        return
    img_copy = map_image.copy()
    
    # Dibujar conexiones
    for node1, node2 in graph.edges():
        x1, y1 = nodes[node1]
        x2, y2 = nodes[node2]
        cv2.line(img_copy, (x1, y1), (x2, y2), (255, 0, 0), 2)
    
    # Dibujar nodos
    for node, (x, y) in nodes.items():
        cv2.circle(img_copy, (x, y), 5, (0, 0, 255), -1)
        cv2.putText(img_copy, node, (x+5, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 1)
    
    # Dibujar ruta si existe
    if path:
        for i in range(len(path) - 1):
            x1, y1 = nodes[path[i]]
            x2, y2 = nodes[path[i + 1]]
            cv2.line(img_copy, (x1, y1), (x2, y2), (0, 255, 0), 3)
    
    cv2.imshow("Mapa Cargado - Haz clic para agregar nodos", img_copy)

# Crear botones en la interfaz
tk.Button(root, text="Cargar Mapa", command=load_image).pack()
tk.Button(root, text="Conectar Nodos (clic en imagen)", command=lambda: cv2.setMouseCallback("Mapa Cargado - Haz clic para agregar nodos", select_nodes)).pack()
tk.Button(root, text="Guardar Grafo", command=save_graph).pack()
tk.Button(root, text="Cargar Grafo", command=load_graph).pack()
tk.Button(root, text="Calcular Ruta", command=calculate_route).pack()
tk.Button(root, text="Salir", command=root.quit).pack()

# Ejecutar la interfaz
tk.mainloop()
