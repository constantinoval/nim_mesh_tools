from typing import Tuple, Dict, List

class Mesh:
    def __init__(self) -> None:
        """
            Класс для работы с сеточной моделью в формате .k.

            Инициализируется без параметров.

            Example
            _______
            >>> from mesh_lib import Mesh
            >>> m = Mesh()
        """
        ...
  
    def read(self, file_path: str) -> bool:
        """
            Чтение сетки из файла.

            Parameters
            __________
            file_path: str
                путь к файлу

            Example
            ________
            >>> m.read("mesh.k")
        """
        ...
  
    def nodescount(self) -> int:
        """
            Возвращает число узлов сеточной модели.

            Returns
            _______
                int: число узлов сеточной модели

            Example
            _______
            >>> print(m.nodescount())
        """
        ...
  
    def solidscount(self) -> int:
        """
            Возвращает число объемных КЭ сеточной модели.

            Returns
            _______
                int: число объемных КЭ сеточной модели

            Example
            _______
            >>> print(m.solidscount())
        """
        ...
 
    def shellscount(self) -> int:
        """
            Возвращает число оболочечных КЭ сеточной модели.

            Returns
            _______
                int: число оболочечных КЭ сеточной модели

            Example
            _______
            >>> print(m.shellscount())
        """
        ...
 
    def solidsorthocount(self) -> int:
        """
            Возвращает число объемных КЭ с материальными осями сеточной модели.

            Returns
            _______
                int: число объемных КЭ с материальными осями сеточной модели

            Example
            _______
            >>> print(m.solidsorthocount())
        """
        ...
 
    def set_tol(self, tol: float = 1e-6) -> None:
        """
            Установка геометрического допуска для функций, например для выбора узлов по координатам.

            Parameters
            _________
            tol: float = 1e-6
                геометрическая точность

            Example
            _________
            >>> m.set_tol(1e-3)

        """
        ...
 
    def save(self, file_path: str) -> None:
        """
            Сохранение сеточной модели в файл file_path.

            Parameters
            __________
            file_path: str
                путь к файлу

            Example
            _________
            >>> m.save("mesh.k")
        """
        ...

    def delete_unreferenced_nodes(self) -> int:
        """
            Удаление из сеточной моди узлов, не принадлежащих коненым элементам. Возвращает число удаленных узлов.

            Returns
            _______
            int: число удаленных узлов

            Example
            _______
            >>> count = m.delete_unrefrenced_nodes()
            >>> print(count)
        """
        ...
 
    def renumber_nodes(self, start: int = 1) -> None:
        """
            Перенумерация узлов модели. Новая нумерация узлов: start..start+nodescount.

            Parameters
            __________
            start: int = 1
                начальный номер узлов после перенумерации
            Example
            _______
            >>> m.renumber_nodes(100)
        """
        ...

    def renumber_shells(self, start: int = 1) -> None:
        """
            Перенумерация оболочек модели. Новая нумерация оболочек: start..start+shellscount.

            Parameters
            __________
            start: int = 1
                начальный номер оболочек после перенумерации
            Example
            _______
            >>> m.renumber_shells(100)
        """
        ...

    def renumber_solids(self, start: int = 1) -> None:
        """
            Перенумерация объемных элементов модели. Новая нумерация объемных элементов: start..start+solidscount.

            Parameters
            __________
            start: int = 1
                начальный номер объемных элементов после перенумерации
            Example
            _______
            >>> m.renumber_solids(100)
        """
        ...

    def renumber_solidsortho(self, start: int = 1) -> None:
        """
            Перенумерация объемных элементов с материальными осями модели.
            Новая нумерация объемных элементов с материальными осями: start..start+solidsorthocount.

            Parameters
            __________
            start: int = 1
                начальный номер объемных элементов с материальными осями после перенумерации
            Example
            _______
            >>> m.renumber_solidsortho(100)
        """
        ...

    def renumber_elements(self, start: int = 1) -> None:
        """
            Перенумерация элементов модели.
            Новая нумерация элементов осями: start..start+shellscount+solidscount+solidsorthocount.

            Parameters
            __________
            start: int = 1
                начальный номер элементов после перенумерации
            Example
            _______
            >>> m.renumber_elements(100)
        """
        ...

    def determinate_bbox(self) -> None:
        """
            Запуск процедуры определения габаритов модели.

            Example
            _______
            >>> m.determinate_bbox()
        """
        ...

    def calculate_element_volumes(self, num_threads: int = 0) -> None:
        """
            Запуск процедуры расчета объемов конечных элементов.

            Parameters
            __________
            num_threads: int =0
                число параллельных потоков
            Example
            _________
            >>> m.calculate_element_volumes(4)
        """
        ...
 
    def bbox(self) -> Tuple:
        """
            Возвращает габариты модели.

            Returns
            __________
            Tuple[float] - (minx, miny, minz, maxx, maxy, maxz)

            Example
            _________
            >>> m.determinate_bbox()
            >>> x0, y0, z0, x1, y1, z1 = m.bbox()
            >>> dx = x1-x0
        """
        ...

    def reflect(self, norm: int = 0) -> None:
        """
            Отражение модели.

            Parameter
            _______
            norm: int
                нормаль

                0 - отражение относительно плоскости YZ,

                1 - относительно плоскости XZ,

                2 - относительно плоскости XY

                default = 0

            Example
            _______
            >>> m.reflect(norm=1)
        """
        ...

    def translate(self, dx: float=0, dy: float=0, dz: float=0) -> None:
        """
            Смещение модели на dx, dy, dz.

            Parameters
            __________
            dx: float = 0 -- смещение по оси 0X

            dy: float = 0 -- смещение по оси 0Y

            dz: float = 0 -- смещение по оси 0Z

            Example
            __________
            >>> m.translate(dy=10)

        """
        ...

    def pairs_for_periodic_bc(self) -> Tuple:
        """
            Поиск пар узлов для периодических граничных условий.

            Returns
            _______
            Tuple - (fixed: int, dx, dy, dz: float, pairs: Dict[string, list[list[2, int]]])

            fixed - индекс узла для закрепления

            dx, dy, dz - размеры сеточной модели по координатным направлениям

            pairs - список пар индексов узлов для периодических граничных условий:
                pairs["plainx"] - пару узлов на плоскостях, параллельных координатной плоскости 0X

                pairs["plainy"] - пару узлов на плоскостях, параллельных координатной плоскости 0Y

                pairs["plainz"] - пару узлов на плоскостях, параллельных координатной плоскости 0Z

                pairs["linesx"] - пару узлов на ребрах, параллельных координатной оси 0X

                pairs["linesy"] - пару узлов на ребрах, параллельных координатной оси 0Y

                pairs["linesz"] - пару узлов на ребрах, параллельных координатной оси 0Z

                pairs["points"] - пары узлов в вершинах ЯП
            Example
            _______
            >>> fixed, dx, dy, dz, pairs = m.pairs_for_periodic_bc()
            >>> print(fixed)
            >>> for n1, n2 in pairs['plainx']:
            >>>     print(n1, n2)
        """
        ...

    def info(self) -> str:
        """
            Строка-информация о сеточной модели.

            Returns
            _______
            str: cтрока-информация о сеточной модели

            Example
            _______
            >>> print(m.info())
        """
        ...
 
    def elements_volumes(self) -> Dict[int, float]:
        """
            Возвращает словарь с объемами 3D КЭ модели.

            Returns
            _______
            Dict[int, float]:
                result[индекс элемента] -> объем элемента

            Example
            _______
            >>> m.calculate_element_volumes(num_threads=4)
            >>> volumes = m.element_voumes()
            >>> print(volumes.get(1, -1))
        """
        ...

    def parts_volumes(self) -> Dict[int, float]:
        """
            Возвращает словарь с объемами частей (parts) сеточной модели.

            Returns
            _______
            Dict[int, float]
                result[part_number] -> объем части с номером part_number

            Example
            _______
            >>> m.calculate_element_volumes(num_threads=4)
            >>> part_volumes = m.part_voumes()
            >>> print(volumes.get(1, -1))
        """

    def parts_numbers(self) -> List[int]:
        """
            Возвращает список частей модели.

            Returns
            _______
            List[int] -- список номеров частей модели

            Example
            _______
            >>> parts = m.parts_numbers()
            >>> if 1 in parts:
            >>>     print(f"Часть с номером 1 есть в модели")
        """
        ...