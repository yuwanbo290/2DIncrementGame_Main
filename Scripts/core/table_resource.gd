@tool
class_name TableResource
extends Resource
## 导表工具产出的表资源。
## 每张 xlsx 表对应一个该资源实例。
## 行数据用「数组」保存而非字典，以支持可重复的 Id。


## 表名（对应 xlsx 文件名，去掉扩展名）
@export var table_name: String = ""

## 行数据：数组（保留重复 Id），每一行是一个 Dictionary（列名 -> 值）
@export var rows: Array[Dictionary] = []
