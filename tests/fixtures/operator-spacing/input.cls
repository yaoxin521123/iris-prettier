/// Creator:WangQingyong
/// Description:动态数组(DynamicArray)扩展
/// 扩展方法(同js数组效果一样):%Concat、%Unshift、%Shift、%Slice、%Splice、%Join、%IndexOf、%Filter、%Sort
Class DHCDoc.Util.Array Extends %RegisteredObject
{

/// 2
/// 11
Parameter apple;

/// 2323
/// 22323
/// 属性
Property array As %DynamicArray [ Private ];

/// 属性
/// 属性
/// 属性
Method %OnNew() As %Status
{
	s $this.array=##class(%DynamicArray).%New()
	Q $this
}

/// 从JSON字符串进行构造
ClassMethod %FromJSON(JsonStr) As DHCDoc.Util.Array
{
	s arr=##class(DHCDoc.Util.Array).%New()
	s arr.array=##class(%DynamicArray).%FromJSON(JsonStr)
	Q arr
}

/// 从原生动态数组进行构造
ClassMethod %FromArray(DynObj As %DynamicArray) As DHCDoc.Util.Array
{
	s arr=##class(DHCDoc.Util.Array).%New()
	s arr.array=DynObj
	Q arr
}

/// 从分割字符串进行构造
ClassMethod %FromStr(Str As %String, Separator As %String = ",") As DHCDoc.Util.Array
{
	s arr=##class(DHCDoc.Util.Array).%New()
	for i=1:1:$L(Str,Separator){
		d arr.array.%Push($P(Str,Separator,i))
	}
	Q arr
}

/// 从入参列表进行构造
ClassMethod %FromArgs(Args...) As DHCDoc.Util.Array
{
	s arr=##class(DHCDoc.Util.Array).%New()
	for i=1:1:+$G(Args){
	   d arr.array.%Push(Args(i))
	}
	Q arr
}

/// 转原生动态数组
Method %ToArray() As %DynamicArray
{
	Q $this.array
}

Method %Set(key As %String, value As %String, type As %String = "") As DHCDoc.Util.Array
{
	s value=##class(DHCDoc.Util.Object).ExtToSys(value)
	if type="" d $this.array.%Set(key,value)
	else  d $this.array.%Set(key,value,type)
	Q $this
}

Method %Get(key As %String)
{
	Q ##class(DHCDoc.Util.Object).SysToExt($this.array.%Get(key))
}

/// 拼接多个数组,不改变原数组
Method %Concat(Arr...) As DHCDoc.Util.Array
{
	s retArr=$this.%ConstructClone()
	for i=1:1:Arr{
		s iter=Arr(i).%GetIterator()
		While iter.%GetNext(.index ,.value ){
			d retArr.%Push(value)
		}
	}
	Q retArr
}

/// 向数组的开头添加一个或更多元素，并返回新的长度
Method %Unshift(Args...)
{
	s NewArr=..%FromArgs(Args...)
	s $this.array=NewArr.%Concat($this)
	Q $this.%Size()
}

/// 删除并返回数组的第一个元素,并返回第一个元素的值
Method %Shift()
{
	Q $this.%Remove(0)
}

/// 选取数组的一部分，并返回一个新数组(不包含最后一个元素)
Method %Slice(start As %Integer, end As %Integer = "") As DHCDoc.Util.Array
{
	s:end="" end=$this.%Size()
	s newArr=##class(DHCDoc.Util.Array).%New()
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.value ){
		if (index>=start)&&(index<end){
			d newArr.%Push(value)
		}
	}
	Q newArr
}

/// 从数组中添加或删除元素,返回删除元素的数组
Method %Splice(index As %Integer, count As %Integer = "", newVal...) As DHCDoc.Util.Array
{
	if count="" s count=$this.%Size()-index
	s EndIndex=index+count-1
	s Args=0
	for i=EndIndex:-1:index{
		s Args=Args+1
		s Args(i-index+1)=$this.%Remove(i)
		
	}
	s delArr=..%FromArgs(Args...)
	s Arr1=$this.%Slice(0,index)
	s Arr2=$this.%Slice(index,$this.%Size())
	s newArr=..%FromArgs(newVal...)
	s $this.array=..Concat(Arr1,newArr,Arr2)
	Q delArr
}

/// 把数组的所有元素放入一个字符串,并返回字符串
Method %Join(Separator As %String = ",") As %String
{
	s retStr=""
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.value ){
		i retStr="" s retStr=value
		e  s retStr=retStr_Separator_value
	}
	Q retStr
}

/// 搜索数组中的元素，并返回它所在的位置
Method %IndexOf(item, start As %Integer = 0) As %Integer
{
	s ret=-1
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.value ){
		continue:index<start
		if value=item{
			s ret=index
			Q
		}
	}
	Q ret
}

/// 数组是否包含元素
Method %Includes(item, start As %Integer = 0) As %Integer
{
	s Find=0
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.value ){
		continue:index<start
		if value=item{
			s Find=1
			Q
		}
	}
	Q Find
}

/// 检测数值元素，并返回符合条件所有元素的数组
/// Express:可用变量value、index、array
/// w ##class(DHCDoc.Util.Array).%FromArray([1,2,5,"a",-1,0]).%Filter("$ISVALIDNUM(value)&&(value>=0)&&(index>0)").%ToJSON()
Method %Filter(Express As %String) As DHCDoc.Util.Array
{
	s retArr=##class(DHCDoc.Util.Array).%New()
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.value ){
		x ("(out,value,index,array) s out="_Express,
					.val,value,index,$this)
		if val{
			d retArr.%Push(value)
		}
	}
	Q retArr
}

/// 对数组的元素进行排序,会改变原始数组
/// ascFlag 1升序 0降序
Method %Sort(ascFlag As %Boolean = 1) As DHCDoc.Util.Array
{
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.value ){
		s PLIST(value)=""
	}
	s newArr=##class(%DynamicArray).%New()
	s order=$CASE(ascFlag,1:1,:-1)
	s value="" for{
		s value=$O(PLIST(value),order) Q:value=""
		d newArr.%Push(value)
	}
	s $this.array=newArr
	Q $this
}

Method %DispatchMethod(Method, Args...)
{
	Q $Method($this.array,Method,Args...)
}

Method %DispatchSetProperty(Property As %String, Value, Args...)
{
	Q ..%Set(Property,Value)
}

Method %DispatchGetProperty(Property As %String, Args...)
{
	Q ..%Get(Property)
}

/// 获取数组默认值(selected为1的值)
Method %GetSelVal(valueField As %String = "id")
{
	s val=""
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.row ){
		if row.selected=1{
			s val=row.%Get(valueField)
			Q
		}
	}
	Q val
}

/// 是否存在某列的置
Method %IsExistVal(value, valueField As %String = "id") As %Boolean
{
	s find=0
	s iter=$this.%GetIterator()
	While iter.%GetNext(.index ,.row ){
		if row.%Get(valueField)=value{
			s find=1
			Q
		}
	}
	Q find
}

/// 拼接多个数组
ClassMethod Concat(Args...) As %DynamicArray
{
	s retArr=[]
	for i=1:1:Args{
		s iter=Args(i).%GetIterator()
		While iter.%GetNext(.key ,.value ) {
			d retArr.%Push(value)
	   }
	}
	Q retArr
}

/// tree data转一般数组模式
ClassMethod TreeDataToArray(data As %DynamicArray) As %DynamicArray
{
	s rows=[]
	for i=1:1:data.%Size(){
		s row=##class(DHCDoc.Util.Object).Extend({},data.%Get(i-1))
		s children=row.children
        d row.%Remove("children")
		d rows.%Push(row)
		if children{
			s rows=..Concat(rows,..TreeDataToArray(children))
		}
	}
    Q rows
}

/// tree data 递归赋值
ClassMethod TreeDataAssign(ByRef data As %DynamicArray, valObj As %DynamicObject)
{
	for i=1:1:data.%Size(){
		s row=data.%Get(i-1)
		d ##class(DHCDoc.Util.Object).Extend(row,valObj)
		if row.children{
			d ..TreeDataAssign(row.children,valObj)
		}
	}
	Q data
}

/// 提取tree data指定属性值
ClassMethod TreeDataPickProp(data As %DynamicArray, PropArr As %DynamicArray)
{
    s rows=[]
    for i=1:1:data.%Size(){
		s row=data.%Get(i-1)
        s newRow={}
		for j=1:1:PropArr.%Size(){
			s PropName=PropArr.%Get(j-1)
			d newRow.%Set(PropName,row.%Get(PropName))
		}
        if (row.children){
            s newRow.children=..TreeDataPickProp(row.children,PropArr)
        }
        d rows.%Push(newRow)
    }
    return rows
}

/// 提取tree data 某个属性为字符串数组
/// 单个每个节点的子节点同属性拼接为字符串,然后将字符串push到数组
ClassMethod TreeDataPickupPropToArr(data, prop, splitChar = "") As DHCDoc.Util.Array
{
	s rows=##class(DHCDoc.Util.Array).%New()
	for i=1:1:data.%Size(){
        s oneStr=""
        s rowArr=##class(DHCDoc.Util.Array).TreeDataToArray([(data.%Get(i-1))])
        for j=1:1:rowArr.%Size(){
            s val=rowArr.%Get(j-1).%Get(prop)
			continue:val=""
			i oneStr="" s oneStr=val
			e  s oneStr=oneStr_splitChar_val
        }
        if oneStr'=""{
            d rows.%Push(oneStr)
        }
    }
	Q rows
}

/// 数组转List,NodeKey为对象数组指定属性生成list
ClassMethod ToList(ByRef OutList, Array As %DynamicArray, NodeKey = "")
{
	k OutList
	for i=1:1:Array.%Size(){
		s row=Array.%Get(i-1)
		if NodeKey'=""{
			s val=row.%Get(NodeKey)
			if (val'=""){
				s OutList(val,$I(OutList(val)))=row
			}
		}else{
			s OutList($I(OutList))=row
		}
	}
	Q 0
}

ClassMethod Test()
{
	#dim arr As DHCDoc.Util.Array
	s arr=..%FromArgs(1,2,3,4,5,6)
	w arr.%ToJSON(),!
	w "%Slice:",!
	w arr.%Slice(1,3).%ToJSON(),!
	w "%Splice:",!
	w arr.%Splice(2,2,"a","b","c").%ToJSON(),!
	w arr.%ToJSON(),!
	w "%Join:",!
	w arr.%Join("^"),!
	w "%IndexOf:",!
	w arr.%IndexOf("b"),!
	w "%Filter:",!
	w arr.%Filter("$ISVALIDNUM(value)&&(value>=0)&&(index>0)").%ToJSON(),!
	w "%Sort:",!
	d arr.%Sort()
	w arr.%ToJSON(),!
	w "TreeDataAssign:",!
	s rows=[{"id":1,"text":"a","code":"a","children":[{"id":1.1,"text":"a1","code":"a1"}]}]
	d ..TreeDataAssign(rows,{"code":"ddd","alias":"aaaaa"})
	w rows.%ToJSON(),!
	w "TreeDataPickProp:",!
	w ..TreeDataPickProp(rows,["id","text"]).%ToJSON(),!
	Q ""
}

}
