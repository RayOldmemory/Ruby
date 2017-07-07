#编写Written by：HRW-CY
#时间Time：5 Jul 2017
#版本Version：1

#该脚本对应于HR Wallingford提供的“示范区级别的海绵模式开发方案评估”
#对应章节为“海绵规划中子集水区的分配”
#由于规划用地的海绵设施分解都是针对地块和道路的，以规划中的地块和道路作为子集水区更加合理，而不必再对地块和道路进行泰森多边形划分子集水区
#该脚本可协助模型工程师对海绵规划中的子集水区进行划分，具体实现的功能包括：
#1.将子集水区的drains to设置为multiple links
#2.将子集水区的lateral weights设置为user
#3.清除lateral links子表中的内容
#4.根据诊断多边形的结果对每个子集水区中的Lateral links对应的节点号、连接后缀、权重进行赋值
#注意，使用该脚本之前，需要模型工程师在ICM界面中手动完成：
#1.绘制一个包围所有子集水区的多边形，生成泰森多边形并转化为非子集水区的类型（比如糙率分区、多边形等）
#2.生成诊断多边形，找到子集水区和泰森多边形重叠的区域
#The functions of this script include:
#1. Set the 'drains to' of subcatchments with 'Multiple links'
#2. Set the 'lateral weights' of subcatchments with 'User'
#3. Clear the sub-table 'Lateral links'
#4. Insert the Lateral links parameters (Node ID, Link suffix and Weight) based on diagnostic polygons
#Before using this script, you should firstly:
#Create a polygon which includes all the subcatchments, then create Thiessen Subcatchments and convert them to other type such as Roughness zone and polygon
#Create diagnostic polygon, find overlay - 2 for subcatchemts and Thiessen polygon

net=WSApplication.current_network
net.transaction_begin

#在哈希ID_Area中存储子集水区的总面积，索引（键）为子集水区编号
#将子集水区的drains to设置为multiple links
#将子集水区的lateral weight设置为user
#清除lateral links子表中的内容
#ID_Area: A hash which contains the total area of subcatchments, the key is subcatchment id
#Set the 'drains to' of subcatchments with 'Multiple links'
#Set the 'lateral weights' of subcatchments with 'User'
#Clear the sub-table 'Lateral links'
ID_Area = Hash.new
net.row_objects('hw_subcatchment').each do |i|
	ID_Area[i.subcatchment_id]=i.total_area
	i.drains_to='Multiple links'
	i.lateral_weights='User'
	i.lateral_links.length = 0
	i.lateral_links.write
	i.write
end

#数组All中存储OVERLAYS - 2的信息。
#数组All的每个元素由五个哈希组成，索引（键）分别为：子集水区编号、节点号、重叠面积、连接后缀和权重
#连接后缀默认为1，权重默认为空值
#All: A array which is consist of hash, the keys are subcatchment id, node id, overlay area, suffix and weight
All = Array.new
net.row_objects('hw_polygon').each do |j|
	if j.category_id == 'OVERLAYS - 2'
		All << {sub_id:j.user_text_1,node_id:j.user_text_2,overlay_area:j.area,suffix:1,weight:''}
	end
end

#根据重叠面积/总面积计算权重，并更新数组All
#Calculate the weights based on overlay area/total area, then update the array All
Weight = Array.new
All.map do |id|
	Weight << id[:overlay_area]/ID_Area[id[:sub_id]]
end
for n in 0...All.size
	All[n][:weight] = Weight[n]
end

#将数组All中每个子集水区中的Lateral links对应的节点号、连接后缀、权重写入模型当中
#insert the data in array All into the sub-table of lateral links
All.map do |n|
	ro = net.row_object('hw_subcatchment',n[:sub_id])
	ll = ro.lateral_links
	ll.length = ll.length + 1
	ll[ll.length-1].node_id = n[:node_id]
	ll[ll.length-1].link_suffix= n[:suffix]
	ll[ll.length-1].weight= n[:weight]
	ll.write
	ro.write
end

net.transaction_commit