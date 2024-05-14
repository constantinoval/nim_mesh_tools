class Mesh:
    def __init__(self) -> None:
        """
            Класс для работы с сеточной моделью в формате .k.
            Инициализируется без параметров.
        """
        ...
    def read(self, file_path: str) -> None:
        """
            Чтение сетки из файла file_path
        """
        ...
    def nodescount(self) -> int:
        """
            Возвращает число узлов сеточной модели
        """
        ...
    