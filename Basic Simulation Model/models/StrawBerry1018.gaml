/**
 *  Strawberry Simulation Model
 *  Author: C 
 *  Description: Simulation Model
 */

model MainModel

global{
	string model_version <- "0921_cn";
	bool simulation_done <- false;
	//ID of the simulation experiment
	int simID <- 22 parameter: 'simulationID' category: 'Simulation';
	//The repetition of the simulation experiment									
	int repeatID <- 8 parameter: 'RepeatID' category: 'Simulation';
	string batchID <- name;
	/*Greenhouse */
	//Length of the greenhouse
	float LANDSCAPE_SIZE_LENTH <- 20.0 parameter: 'Greenhouse_lenth' category: 'Greenhouse';//20,80
	//Width of the greenhouse
	float LANDSCAPE_SIZE_WIDTH <- 8.0 parameter: 'Greenhouse_width' category: 'Greenhouse';
	//草莓种植时距离温室上方和左方的边距
	float left_margin <-4.5 parameter: 'left_margin' category: 'Greenhouse';
	float top_margin <-0.5 parameter: 'top_margin' category: 'Greenhouse'; 
	geometry shape <- rectangle(LANDSCAPE_SIZE_LENTH *1.1, LANDSCAPE_SIZE_WIDTH *1.1);
	//温室的边界，也是蜜蜂飞行的边界 
	geometry field_boundary <-  shape scaled_to {LANDSCAPE_SIZE_LENTH, LANDSCAPE_SIZE_WIDTH};
	//The center
	point CENTER -> {{round(LANDSCAPE_SIZE_LENTH/2),round(LANDSCAPE_SIZE_WIDTH/2)}};

	/*Field plants */
	                                                           			
	int ovules_in_first_inflorescence <- 350;	//一级花350个雌蕊
	int ovules_in_second_inflorescence <- 260;	//二级花280个雌蕊
	int ovules_in_third_inflorescence <- 180;	//三级花180个雌蕊，本实验中不使用
	
	/*Strawberry */
	//The strawberry number in a row
	int nb_clones_column <-60 parameter: 'Strawberry_column' category: 'Strawberry';//390,20
	//草莓种植行数
	int nb_clones_row <-12 parameter: 'Strawberry_row' category: 'Strawberry';
	//第一朵花开放的天数
	int bloom_day <- 0;
	//草莓开花的base temperature
	int T_base_strawberry_for_bloom <- 0;
	//草莓果实生长的base temperature
	int T_base_strawberry_for_ripeness <- 6;            
	//草莓花期为5天
	int days_strawberry_bloom <- 5;  
	//控制花序等级，本实验中每朵花仅保留三个花序     
	float probability_of_clone_with_three_inflorescence <- 1.0;
	//草莓自亲和性,参数
	float strawberry_self_compatibility_probability <- 0.8 parameter: 'Strawberry_self_compatibility' category: 'Strawberry';
		
	/*Scheduling */
	//未开花前cycle_per_day=1,开花后540，9 hours * 60 cycles per hour = 540 cycles per day
	int cycle_per_day <- 1;	
	//记录每日的具体时刻，从8点至17点				
	int time_8_to_17 <- 0;
	int time_minute <- 0;
	//是否是整点
	bool is_clock <- false;
	
	/*Weather */
	float max_temperature <- 0.0;
	float min_temperature <- 0.0;
	float mean_daily_temperature;
	float wind_speed <- 0.0;
	float rainfall <- 0.0;
	float leaf_wetness <- 0.0;
	
	/*Phenology */
	//The Julian day when the simulation starts on
	int START_JULIAN <- 1; 		//1st of January according
	float INIT_GDD <- 0.0;
	int mean_gdd_primary <- 586;		//草莓一级花序开花所需要的GDD均值, 586摄氏度
	int mean_gdd_secondary <- 946;      //草莓二级花序开花所需要的GDD均值, 1066摄氏度
	int sd_gdd <- 120;					//草莓开花所需要的GDD方差
	
	int mean_gdd_ripeness <- 284;       //草莓果实成熟需要的GDD均值
	int sd_gdd_ripeness <- 30;			//草莓果实成熟需要的GDD方差
	
	float GDD;	
	int current_julian <- START_JULIAN update: growth_days_elapsed + START_JULIAN;
	int growth_days_elapsed <- 0;
	int growth_start_on <- 0;
	int days_after_bloom <- 0;
	
	/*Pollinator */
	int memory_length <- 5;                         //the number of visited stems that a bee can remember
	//蜜蜂的每次活动使用一分钟进行模拟
	float minute_per_step <- 1.0;					
	//蜜蜂最大的携带花粉数量，设置足够大
	int max_pollen_load <- 500000;                  
	//蜂箱的摆放位置，一般放置在温室东侧
	float hive_Location_X <- 1.04 parameter: 'hive_Location_X' category: 'Greenhouse';
	float hive_Location_Y <- 0.5 parameter: 'hive_Location_Y' category: 'Greenhouse';
	point Hive_Location_Strawberry <-{LANDSCAPE_SIZE_LENTH*hive_Location_X,LANDSCAPE_SIZE_WIDTH*hive_Location_Y};
	//point Hive_Location_Strawberry <-{LANDSCAPE_SIZE_LENTH*0.5,LANDSCAPE_SIZE_WIDTH*1};
	//大棚中蜜蜂的数量，一箱意大利蜜蜂的数量是3500~4000左右，外勤工蜂比例是40%
	int nb_honybee_on_hive <- 200 parameter: 'Honybee_on_hive' category: 'Honybee';
	float ratio_bee_worker <- 0.4 parameter: 'Ratio_bee_worker' category: 'Honybee';
	int nb_honybee_on_strawberry <- int(nb_honybee_on_hive*ratio_bee_worker);
	//int nb_honybee_on_strawberry <- int(nb_clones_column*nb_clones_row*0.1); 		
	//不同时刻赋予蜜蜂不同的出巢率
	float honeybee_activity_ratio <-0.0;
	//温室中觅食的蜜蜂数量
	int nb_foraging_pollen <-0;
	//蜜蜂一次外出觅食访问的花序数量
	int honeybee_wordload <- 14 parameter: 'Honeybee_wordload' category: 'Honybee';
	//int honeybee_within_stem_visits <- 4 parameter: 'Honeybee_within_stem_visits' category: 'Honybee';
	//蜜蜂在温室内的最大飞行距离
	float honeybee_max_travel_dist <- 1000 #m parameter: 'Honeybee_max_travel_dist' category: 'Honybee';
	//蜜蜂访问花朵时，一次提取的花粉数量
	int honeybee_pollen_extracted_per_visit <- 9000 parameter: 'Honeybee_pollen_extracted_per_visit' category: 'Honybee';
	//Become active when any flower is opening
	bool is_active <- false; 
		
	/*Interruptions */
	//bool reach_field_density <- false;
	bool clone_init_done <- false;
	bool simulation_started <- false;
	//温室内是否已经开花，驱使蜜蜂外出觅食
	bool flower_in_bloom <- false;
	
	/*Field level attributes */
	//温室整体开花率
	float percent_flower_open;
	//温室整体果实成熟率
	float percent_fruits_ripeness;
	//温室整体果实正在发育的比例
	float percent_fruits_for_ripeness;
	//平均果实质量
	float avg_fruit_mass;
	float sd_fruit_mass;
	float avg_nb_seeds;
	float sd_nb_seeds;
	float percent_fruit_set;
	float percent_fruit_setII;
	//每株草莓平均果实数量
	float avg_healthy_berries; 
	float kg_yields_ha;	
	//总体畸形果率
	float percent_malformed_berries;
		
	//读入温室天气数据
	string weather_file_path <- "../includes/Weather-Strawberry-Greenhouse.csv";    
	file weather_file <- csv_file(weather_file_path,",");
	matrix weather_data <- matrix(weather_file);
	//天气数据文件路径
	string weather_path <- copy_between(weather_file_path, 0, length(weather_file_path));
	//模拟持续的天数, 草莓实验中为110
	int simulation_duration <- int(max(columns_list(weather_data)[0]));
	
	/*System */
	/*Graphical option */
	//是否展示备注信息
	bool show_screentext <- true;
	//是否展示蜜蜂
	bool show_pollinators <- true;      
		
	init {	
		//Create System scheduling entity	
		create SystemMonitor number:1{
		}	
		//Create Phenology entity
		create Phenology number:1{		
		}
		//积温初始化0
		GDD <- INIT_GDD;	
		if(true){    
			//Generate strawberry landscape from scratch
			ask self{
				//generate bluberry fields as default geometry (square, being identical to the environment)
				if(true){		
					//在温室生成草莓植株
					do strawberryclone_growth(field_boundary);
				}
			}
		}
		
		create Clone_indices number:length(StrawberryClone){} 				
		create Flower_indices number:(length(StrawberryClone)*12){} 			
	}
		
	reflex sytem_scheduling {
		//Real simulation still has NOT started
		if(simulation_started){
			//仿真进行一天
			if((cycle - growth_start_on) mod cycle_per_day = 0){	
				growth_days_elapsed <- growth_days_elapsed + 1; 
			}
		}
	}	
	//更新蜜蜂是否觅食, 为了节省内存, 必须在已经开花了, 并且果实没有全部成才
	reflex update_bee_active {
		if(flower_in_bloom){
			if((percent_fruits_ripeness+percent_fruits_for_ripeness)=1){
				is_active <- false;
			}
			else{
				is_active <- true;
			}
		}
	}
	
	//进行到110天时，草莓仿真结束
	reflex halt_simulation {
		if(current_julian > simulation_duration){					
			simulation_done <- true;			
		}
	}
	
	//将仿真的cycle转为具体的时间
	reflex convert_cycle_to_time{
		if (flower_in_bloom){
			//计算每日的具体时刻，范围是8点-17点
			int time_8_to_17_temp <- (cycle-bloom_day) mod (9*60);
			time_8_to_17 <- int(time_8_to_17_temp/60)+8;
			time_minute <- time_8_to_17_temp mod 60;
			//是否为整点，蜂巢释放蜜蜂
			if (time_8_to_17_temp mod 60 = 0){
				is_clock <-true;
			}
			else{
				is_clock <-false;
			}			
		}
		//根据每日的时刻赋予蜜蜂不同的出巢率
		if(time_8_to_17 = 8){
			honeybee_activity_ratio <-0.0;
		}
		else if(time_8_to_17 = 9){
			honeybee_activity_ratio <-0.0;
		}
		else if(time_8_to_17 = 10){
			honeybee_activity_ratio <-0.0113;//1.13%
		}
		else if(time_8_to_17 = 11){
			honeybee_activity_ratio <-0.0203;//2.03%
		}
		else if(time_8_to_17 = 12){
			honeybee_activity_ratio <-0.0270;//2.70%
		}
		else if(time_8_to_17 = 13){
			honeybee_activity_ratio <-0.0315;//3.15%
		}
		else if(time_8_to_17 = 14){
			honeybee_activity_ratio <-0.0260;//2.60%
		}
		else if(time_8_to_17 = 15){
			honeybee_activity_ratio <-0.012;//1.20%
		}
		else if(time_8_to_17 = 16){
			honeybee_activity_ratio <-0.0;
		}
		else if(time_8_to_17 = 17){
			honeybee_activity_ratio <-0.0;
		}
	}
	
	//Randomly set strawberry clones as small circles
	action strawberryclone_growth (geometry geo_field_boundary) {		//草莓种植方式的模型
		//Create the strawberry clones                                                             
		loop i from:1 to:nb_clones_column{ 	
			loop j from:1 to:nb_clones_row{
				//每株草莓半径为0.1m, 垄间距0.4m+0.1m+0.1m 
				geometry tmp_geo1 <- circle(0.1) at_location {left_margin+0.2*i,top_margin+0.6*j};
				geometry tmp_geo2 <- circle(0.1) at_location {left_margin+0.2*i,top_margin+0.2+0.6*j};
				//每垄两行草莓,第一行
				create StrawberryClone number:1{
					shape <- tmp_geo1;
				}
				//每垄两行草莓,第二行
				create StrawberryClone number:1{
					shape <- tmp_geo2;
				}	
			}				
		}		
	}
}

species Clone_indices {
	/*Clone level attributes */
	/*Flower and fruit */
	string clone_ID;
	float clone_size;
	point clone_location;
	float clone_location_x;
	float clone_location_y;

	float clone_avg_beevisits_stem;
	float clone_openflower_percentage;
	float clone_fruitset_mean;
	float clone_fruitset_std;
	float clone_fruitsetII_mean;
	float clone_fruitsetII_std;
	float clone_fruitmass_mean;
	//float clone_fruitmass_std;
	float clone_seeds_mean;
	float clone_seeds_std;	
	float clone_pollen_accepted;
	float clone_pollen_received;
	//每株草莓的果实数量, 使用整数
	int clone_healthy_berries;
	//每株草莓的畸形果实数量, 使用整数
	int clone_malformed_berries;
	float clone_percent_malformed_berries;
}

species Flower_indices {
	//花朵编号
	int Flower_ID <- -1;
	//花朵所在的植株编号
	int Flower_in_clone_ID<- -1;
	//花朵所在的花序等级，1和2
	int Flower_in_inflorescence_ID<- -1;
	//蜜蜂访问次数
	float Flower_beevisits<- -1.0;
	//花朵开放时间
	int Flower_bloom_day<- -1;
	//花朵(果实)成熟时间
	int Flower_ripeness_day<- -1;
	//花朵果实质量
	float Flower_fruit_mass <- -1.0;
	//是否畸形果, 2表示正常, 1表示畸形果, 0表示未生长
	int Flower_beery_malformed <- -1; 
	//该花被蜜蜂访问的次数
	int Flower_bee_visit <- -1; 
	int Flower_nb_pollen_native <- 0;
	int Flower_nb_pollen_foreign <- 0;
}


//Phenology entity, 主要用来更新天气情况
species Phenology use_regular_agents: false use_individual_shapes: false schedules: (every (cycle_per_day ) and simulation_started)? Phenology: []{		
	action get_temperature (int x_julianday){
		//Calculation in Celsius 
		//max_temperature <- (float(weather_data[1, x_julianday - START_JULIAN]) - 32)/1.8;
		//min_temperature <- (float(weather_data[2, x_julianday - START_JULIAN]) - 32)/1.8;
		//GDD in degree Celsius 
		max_temperature <- float(weather_data[1, x_julianday - START_JULIAN]);
		min_temperature <- float(weather_data[2, x_julianday - START_JULIAN]);
		mean_daily_temperature <- (max_temperature + min_temperature)/2;
	}
	
	//Calculate growth degree day, 计算GDD
	reflex accumulating_degree_day{
		do get_temperature(current_julian);
		//Strawberry, referred to Impact of climate change on the timing of strawberry phenological...
		GDD <- GDD + max([(mean_daily_temperature - T_base_strawberry_for_bloom), 0]);
	}
}

//Nest entity
species Nest  use_regular_agents: false use_individual_shapes: false {
	int ID;	
	//蜂巢的坐标
	float Loc_x;
	float Loc_y;
	//蜂巢的颜色
	rgb color;
	//蜂巢的位置
	init{
		location <- Hive_Location_Strawberry;
	}
}

//Parent entity for bees 
species Pollinator control:fsm skills:[moving] {
	float max_travel_dist;
	//target目标花
	Stem target <- nil;
	list visit_history <- nil;
	int workload <- 0;
	point nest;
	Nest Nest; 
	rgb color <- #white;
	int failed_searches <- 0;
	//蜜蜂状态，0巢穴，1寻找花，2访问花
	int bee_state <- 0;									
	
	float dist_traveled <- 0.0;
	bool in_nest <- true;
	//蜜蜂已经访问的花序数
	int reward_collected <- 0;
	//传粉者的速度, 会被蜜蜂类覆盖
	float max_speed <- 7.0 #m/#s;
	float min_speed <- 0.5 #m/#s;
	float azimuth;                 //方位角
	//传粉者的信息, 会被蜜蜂类覆盖
	int nb_pollen_deposited_per_visit <- 25;	
	int nb_pollen_extracted_per_visit <- 42;
	//目前携带的花粉数量
	int nb_pollen_carring <- 0;
	
	//weather conditions affecting pollinator foraging	
	float foraging_temperature_Lbound <- 30.0;		//C
	float foraging_temperature_Ubound <- 15.0;		//C
	float foraging_wind_limit <- 25.0;//mph
	float foraging_rainfall_limit <- 1.67;//inch
	
	
	//Unit of pollen basket for recording pollen genotype and number of grains
	//pollen_basket记录Clone的基因类型，
	species pollen_basket use_regular_agents: false use_individual_shapes: false{
		StrawberryClone pollen_genotype;
		int nb_pollen_grains <- 0;					//蜜蜂携带的花粉数量
	}

	reflex status_update when: is_active {
		nb_pollen_carring <- sum(pollen_basket collect each.nb_pollen_grains);
	}
	
	state stay_nest initial: true{
		enter{
			//Initialize status
			reward_collected <- 0;
			speed <- 0.0;
			location <- nest;
			dist_traveled <- 0.0;
			color <- #purple;
			
			//Unload pollen from pollen basket
			if(!empty(pollen_basket)){
				ask pollen_basket{
					do die;
				}
			}		
		}
		bee_state <- 0;
		//Leave nest to search flower if any flower presents in the field and weather condition is suitable for flight	
		//transition to: search_flower when: is_active and weather_check()and flip(percent_flower_open); 
		//transition to: search_flower when: is_active and weather_check() and flip(honeybee_activity_ratio) and is_clock; 
		transition to: search_flower when: is_active and flip(honeybee_activity_ratio) and is_clock; 
		
		exit{
			//Randomly assign workload
			do assign_workload();

			//Leave the nest at average speed
			speed <- (max_speed + min_speed)/2.0;
			
			if(!empty(visit_history)){
				//Heading for the last rewarding clone
				location <- Stem(first(shuffle((visit_history)))).host_clone.location;
			}
			//Find one of clone in bloom
			else{                                                 
				//蜜蜂初始采蜜的花序
				location <- any(shuffle(Stem where (each.inflorescence_in_bloom = true) )).location;
				//将盛开的花通过与蜂巢的距离进行排序
				list<Stem> Stem_sorted<-Stem where (each.inflorescence_in_bloom = true) sort_by (distance_to(each.location,nest));
				//list<Stem> Stem_sorted_rank<-Stem_sorted;
				//Updated by Cao to show the procedure
				//初始位置集中在最近的盛开花序	
				if(flip(0.8)){                                    
					//location <- Stem_sorted[0].location;          
				}
			}	
			//Accumulate traveled distance
			dist_traveled <- dist_traveled + location distance_to nest;
		}
	}
	
	state search_flower {
		//Change speed according to the number of failure in search
		speed <- max([max_speed * (1 - exp(-failed_searches)), min_speed]);  //寻找花的速度，修改
		//speed <-0.01 #m/#s;
		color <- #pink;
		//color <- #gray;
		bee_state <- 1;
		
		//Random flight
		do wander speed:speed amplitude: rnd(azimuth) bounds:field_boundary; //蜜蜂飞行的范围修正
		//Search flower in bloom
		do target_detect();
		//Increase the failure count
		failed_searches <- failed_searches + 1;
		
		//Accumulate traveled distance
		dist_traveled <- dist_traveled + speed;
		//Visit flower if a bloom stem has been found		
		transition to: visit_flower when: is_active and (target != nil);
		//Go back to nest if weather condition is not satisfied, or has traveled too far during the current bout
		transition to: stay_nest when: (!is_active) or (dist_traveled > max_travel_dist) or(time_8_to_17=8);
		
	}
	state visit_flower{	
		//Assign # of flower visits within the stem that the bee is currently landing on
		int nb_visits_in_stem <- 10;
		int nb_reward <- 0; 
		color <- #black;
		//蜜蜂飞到目标花上
		location <- target.location;
		//bee_state为2表示为访花阶段
		bee_state <- 2;
		//If current stem is in bloom and should visit some flowers
		if(target.flower_state = 1 and nb_visits_in_stem >0){
			//target:stem
			nb_reward <- pollinator_stem_contact (target, min([target.nb_flowers_in_inflorescence, nb_visits_in_stem]));
			failed_searches <- 0;
		}
		//Accumulate reward
		reward_collected <- nb_reward > 0 ? (reward_collected + 1) : reward_collected;		
		
		//Memorize visited stems
		visit_history <- visit_history + target;	
		//Forget the earliest stems in its memory 
		if (length(visit_history) >= memory_length) {
			visit_history <- visit_history - first(visit_history);
		}
		
		//Count for bee density for the clone it currently visiting
		target.host_clone.bee_density_counter <- target.host_clone.bee_density_counter + 1;
		target.nb_bee_visit_stem <- target.nb_bee_visit_stem + 1;
		
		//Leave current stem
		target <- nil;	
		
		//Go back to nest when enough reward has been collected or has been traveled too far		
		transition to: stay_nest when: (reward_collected >= workload) or (dist_traveled > max_travel_dist) or (time_8_to_17=8);
		//Start searching again if still needs get more reward 
		transition to: search_flower when: (target = nil) and (reward_collected < workload);
	}
	
	//Extract pollen from flower it is currently landing on
	//一朵花一个基因型，每朵花的基因型都不一样	
	action pollen_extacting (int xnb_pollen_grains, StrawberryClone x_genotype){
		//If its pollen basket still has empty place
		if(nb_pollen_carring < max_pollen_load){
			//basket_indicator is an temporary variable to judge if the bee has already carried this type of pollen...remarked by Cao
			list<pollen_basket> basket_indicator <- self.pollen_basket select (each.pollen_genotype = x_genotype);
			if(empty(basket_indicator)){
				//The pollen basket doesnt have this type of pollen grains so far
				create pollen_basket number:1{
					pollen_genotype <- x_genotype;             //pollen_basket的两个属性
					nb_pollen_grains <-  xnb_pollen_grains; 
				}
			}
			//If the pollen basket already has this type of pollen, then load them to the right place
			else{
				basket_indicator[0].nb_pollen_grains <- basket_indicator[0].nb_pollen_grains +  xnb_pollen_grains;
			}			
		}
	}
	
	//Search stem in bloom and that has not been visited recently in its perception range, circle with radius of 1m around the bee
	action target_detect {
		//target是花序，可以显性显示
		target <- shuffle(Stem at_distance 1.0 - visit_history) first_with (each.flower_state=1);
	}

	//Drop off empty pollen basket
	action remove_empty_basket{
		list<pollen_basket> empty_basket <- pollen_basket where (each.nb_pollen_grains <=0);
		loop b over: empty_basket{
			ask b{
				do die;
			}
		}	
	}
	
	//@parameter
	//x_target: the stem the bee will contact
	//xnb_visits: the number of flowers bee will contact explicitly
	
	//包含了Deposit pollen + Extract pollen两个过程
	//第一个参数为访问的花序，第二个参数为每个花序访花数量
	action pollinator_stem_contact (Stem x_target, int xnb_visits) type: int{
		//int nb_actual_flower_visits <- 0;
		int nb_successful_visits <- 0;
		
		//Avoid exception that the number of flower is less than expectation
		//nb_actual_flower_visits <- min([xnb_visits, x_target.nb_flowers_in_inflorescence]);
		
		//Do NOT use ask statement, which may cause the object to be locked unitl the completion of access
		//ask x_target{
		//蜜蜂遍历花序上全部花朵
		loop k from:0 to:(length(x_target.Flower) - 1){	
			if(x_target != nil){
				//Randomly choose flower to visit		
				int i <- k;
				//write "length(x_target.Flower)  / i :" + length(x_target.Flower);				
				//the flower is healthy
					//Deposit pollen
					//一个具体的pollen_basket只携带一个种类型的花粉 
					int nb_pollen_types <- pollen_basket count (each.nb_pollen_grains > 0);
					
					if((x_target.Flower[i].nb_received_pollen < x_target.stigma_capacity) and nb_pollen_types > 0 and nb_pollen_carring > 0){
						
						//nb_actual_pollens卸载的花粉数
						//nb_pollen_deposited_per_visit每次访问卸载的花粉数量，set to 25
						int nb_actual_pollens <- min([nb_pollen_carring, nb_pollen_deposited_per_visit]);
						loop p over:pollen_basket{
							//真正交互的花粉数*本花粉篮子中的花粉数/本蜜蜂携带的花粉数，把每个篮子中的花粉平均卸载
							int nb_deposited <- int(nb_actual_pollens * p.nb_pollen_grains / nb_pollen_carring);
							p.nb_pollen_grains <- p.nb_pollen_grains - nb_deposited;
													
							bool pollen_compatibility <- false;
							//同珠草莓花授粉
							if(p.pollen_genotype = x_target.host_clone){
								//自花授粉的情况
								pollen_compatibility <- flip(x_target.host_clone.self_pollen_compatibility);
								//pollen_compatibility <- flip(1);
							}
							//Allien pollen is always acceptable
							//异珠授粉百分之百
							else{        
								pollen_compatibility <- true;
							}
							//Check pollen compatibility and receptivity
							//If it is receptable
							//花粉必须先通过receptivity, 再通过compatibility
							if(flip(x_target.pollen_receptivity)){			//pollen_receptivity是收到柱头的影响
								//int tmp_acceptable_pollen <- min([x_target.Flower[i].nb_accepted_pollen + nb_deposited, x_target.Flower[i].nb_available_ovules]);
								//If it is testing hypothesis H1

								//If it is compatible
								if(pollen_compatibility){			
									x_target.Flower[i].nb_accepted_pollen <- x_target.Flower[i].nb_accepted_pollen + nb_deposited;
									x_target.Flower[i].nb_available_ovules <- x_target.Flower[i].nb_available_ovules - nb_deposited;
									//如果是同珠授粉
									if(p.pollen_genotype = x_target.host_clone){ x_target.Flower[i].nb_pollen_native<-x_target.Flower[i].nb_pollen_native-1;}
									//如果是异珠授粉
									else { x_target.Flower[i].nb_pollen_foreign<-x_target.Flower[i].nb_pollen_foreign-1;}
								}
								//If it is not compatible
								else{
									//Do nothing?
								}	

								//Impact of pollen accumulations on later coming pollens should be considered 
								//Once receptivity test passed, decrease avlaible stigma space
								x_target.Flower[i].nb_received_pollen <- x_target.Flower[i].nb_received_pollen + nb_deposited;
							}
						
							//received_pollen是卸载到柱头上的花粉数量，不要超过stigma_capacity
							//accepted_pollen是被花接受可以传递生物信息的花粉数量，注意不要超过该花所有的胚珠数量ovules_in_N_inflorescence
							//一级花序
							if(x_target.inflorescence_position = 1 ){
								x_target.Flower[i].nb_accepted_pollen <- min([x_target.Flower[i].nb_accepted_pollen, ovules_in_first_inflorescence]);
							}
							//二级花序
							else if (x_target.inflorescence_position = 2 ){
								x_target.Flower[i].nb_accepted_pollen <- min([x_target.Flower[i].nb_accepted_pollen, ovules_in_second_inflorescence]);
							}
							//三级花序
							else{
								x_target.Flower[i].nb_accepted_pollen <- min([x_target.Flower[i].nb_accepted_pollen, ovules_in_third_inflorescence]);
							}
							x_target.Flower[i].nb_received_pollen <- min([x_target.Flower[i].nb_received_pollen, x_target.stigma_capacity]);
							x_target.Flower[i].nb_available_ovules <- max([x_target.Flower[i].nb_available_ovules, 0]);
							//用于展示花朵剩余胚珠数量
							//write "current_julian" + current_julian;
							//write "nb_available_ovules"+x_target.Flower[i].nb_available_ovules;
							//write "Flower:" + x_target.Flower[i] + " accepted pollen: " + x_target.Flower[i].nb_accepted_pollen;
						}		
									
						//Remove empty baskets
						do remove_empty_basket();
					}
					
					//Extract pollen 
					if(x_target.Flower[i].nb_gen_pollen > 0 and x_target.Flower[i].fruit_mass >= 0){
						int extracted_pollen <- min([nb_pollen_extracted_per_visit,x_target.Flower[i].nb_gen_pollen]);
						do pollen_extacting(extracted_pollen, x_target.host_clone);
						x_target.Flower[i].nb_gen_pollen <- x_target.Flower[i].nb_gen_pollen - extracted_pollen;
						
						//A successful visit
						nb_successful_visits <- nb_successful_visits + 1;
					}			
			}
		}
		return nb_successful_visits;
	}
		
	//pollinator的任务量, 会被覆盖
	action assign_workload {
		workload <- 200;
	}

	//This function will be overrided by certain bee species	
	//Check weather condition to decide whether flight or not
	action weather_check type:bool{
		//bool weather_ok <- false;
		bool weather_ok <- true;
		//float relative_foraging_activity <- (foraging_rainfall_limit - rainfall)/foraging_rainfall_limit;
		//if((mean_daily_temperature >= foraging_temperature_Lbound and mean_daily_temperature <= foraging_temperature_Ubound) /*and 
		  //(wind_speed <= foraging_wind_limit) and (rainfall <= foraging_rainfall_limit)*/){
		  	//if(flip(relative_foraging_activity)){
		  		//weather_ok <- true;
		  	//}
		//}
		return weather_ok;
	}
	
	aspect my_aspect {
		if(show_pollinators){
			//Display color for different bee species
			//draw circle(0.04) color: target = nil ?color:°white;
			draw circle(0.02) color: color;
		}
	}
}

species Honeybee parent:Pollinator schedules:shuffle(Honeybee){
	//rgb color <- °purple;
	//蜜蜂每次访花时, 卸载的花粉数
	int nb_pollen_deposited_per_visit <- int(100*0.3);  
	int nb_pollen_extracted_per_visit <- honeybee_pollen_extracted_per_visit;
	//蜜蜂可以外出觅食的温度为15-30摄氏度
	float foraging_temperature_Lbound <- 15.0;
	float foraging_temperature_Ubound <- 30.0;
	float foraging_wind_limit <- 25.0;//mph
	float foraging_rainfall_limit <- 1.0;//inch
	//蜜蜂的最大和最小飞行速度
	float max_speed <- 5.1 #m/#s;
	float min_speed <- 0.1 #m/#s;//3.3 #m/#s;
	//蜜蜂的最远飞行距离, 仿真参数
	float max_travel_dist <- honeybee_max_travel_dist;
	float azimuth <- 90.0;
	
	//蜜蜂一次觅食访问的stem数量, 仿真参数
	action assign_workload{   
		workload <- honeybee_wordload;
	}
	
	action weather_check type:bool{
		bool weather_ok <- false;
		
		if((mean_daily_temperature >= foraging_temperature_Lbound and mean_daily_temperature <= foraging_temperature_Ubound) /*and
			(wind_speed <= foraging_wind_limit) and (rainfall <= foraging_rainfall_limit)*/){
		  	weather_ok <- true;
		}
		return weather_ok;
	}			
}

species Stem use_regular_agents: false use_individual_shapes: false schedules: [] {
	//The clone it is located
	StrawberryClone host_clone;
	//花序的位置, 1:fist; 2:second; 3:third	
	int inflorescence_position <-2;		  				
	//草莓每个花序上的花朵数
	int nb_flowers_in_inflorescence <- 6;								  
	int nb_open_flower <-0;	
	
	/*Pollinator related attributes */
	float avg_nb_seeds_per_stem <- 0.0;
	float avg_fruit_mass_per_stem <- 0.0;
	float yield_per_stem <- 0.0;
	float fruit_set_per_stem <- 0.0;
	float fruit_set_per_stem_II <- 0.0;	
	float avg_nb_accepted_pollen <- 0.0;
	float avg_nb_received_pollen <- 0.0;
	
	//该花序上的果实数量(包含畸形果)
	int nb_healthy_berries_stem <- 0;
	//该花序上的畸形果数量
	int nb_malformed_berries_stem <- 0;
	
	//花朵的状态, 0发芽期, 1开花期, 2果实发育期, 3果实成熟期
	int flower_state <- 0;  
	//花龄
	int flower_age <- 0;                                                  
	//花粉的接受概率
	float pollen_receptivity;                                             
	//草莓柱头上能承载的花粉数量	
	int stigma_capacity <- 0; 
	//草莓开花所需要的GDD
	int inflorescence_bloom_heat;
	//草莓果实成熟所需要的GDD										  
	int inflorescence_berry_ripeness_heat;
	bool inflorescence_in_bloom <- false;								  //花序是否开花
	bool whether_initial <- true;										  //Stem第一次被创建
	//草莓果实生长积累的GDD
	float GDD_ripeness<- 0.0;
	int inflorescence_bloom_day;                                      //花序开花时间
	int inflorescence_ripensess_day;                                  //花序对应果实成熟时间
	rgb color_for_figure;
	int nb_bee_visit_stem <- 0;
	
	species Flower use_regular_agents: false use_individual_shapes: false schedules: []{
		//The # of available ovules
		int nb_available_ovules <- 0;
		int nb_all_ovules <- 0; 
		//The # of received pollen grains
		int nb_received_pollen <- 0;                                      //卸载到柱头上的花粉数量，条件比较简单，不要超过stigma_capacity
		//The # of accepted pollen grains
		int nb_accepted_pollen <- 0;                                      //花接受可以传递生物信息的花粉数量，注意不要超过该花所有的胚珠数量
		//The # of produced pollen grains
		//18000 * 25 = 450000
		int nb_gen_pollen <- 450000;                                      //每朵花的花粉粒总数
		int nb_fertilized_ovules <- 0;                                    //受孕的胚珠数量，=花接受的花粉粒数量
		int nb_achenes <- 0;											  //瘦果数量，=受孕的胚珠数量
		float fruit_mass <- 0.0;                                          //根据可育种子数估算的浆果质量
		int nb_pollen_native <- 0;  
		int nb_pollen_foreign <- 0;
		
	}
								
	aspect my_aspect {
		//Stem color: Bud-green; Blooming-pink; Blooming ends-red
		//For stem bearing fruits, the higher the fruit set, the brighter the red color
		//draw square(0.1) color: (flower_state=0)?°green:((flower_state=1)?°yellow:rgb(55+200*fruit_set_per_stem, 0, 0));
		
		//flower_state=0，绿色，发芽期
		if (flower_state=0){
			color_for_figure <-°green;
		}
		//flower_state=1，黄色，开花期
		else if (flower_state=1){
			color_for_figure <-°yellow;
		}
		//flower_state=2，粉色，果实生长期
		else if (flower_state=2){
			color_for_figure <-°pink;
		}
		//flower_state=3，红色，果实已成熟
		else if (flower_state=3){
			color_for_figure <-°red;
		}
		if (inflorescence_position =1 ){
			draw circle(0.035) color: color_for_figure;
		}
		else if (inflorescence_position =2 ){
			draw circle(0.02) color: color_for_figure;
		}
		else{
			draw circle(0.015) color: color_for_figure;
		}
	}
}

species StrawberryClone {
	//The all stems the clone contains
	list<Stem> list_stems;                    
	int nb_stems;
	//草莓植株的占地面积
	float clone_area update: shape.area;	

	//Probability of acceptance of self pollen
	float self_pollen_compatibility;
	//Whether the stems have been initialized
	bool has_stem <- false;
	//植株的蜜蜂访问次数
	int bee_density_counter <- 0;
	
	init{
		// Calculate the probability of acceptance of self pollen
		//给每一个草莓植株赋予不同的自花适应概率
		do init_self_pollen_compatibility();
	}
		
	//Populate stems into the clone                                              使用stems填充clone
	//reflex populate_stem when: !has_stem and reach_field_density{	20111124 revised -- parallel collision resolved
	action populate_stem {
		//用于绘制花序
		float size_inflorescence;   	//3 or 4
		if(flip(probability_of_clone_with_three_inflorescence))
		{
			size_inflorescence <- 0.06; //0.06 is suitable for 3 inflorescences empirically
		}
		else
		{
			size_inflorescence <- 0.05; //0.05 is suitable for 4 inflorescences empirically
		}
		list<geometry> stem_loc <- to_squares(shape, size_inflorescence,false);
		list<geometry> stem_loc_sorted <- stem_loc sort_by (each.location.x+each.location.y);
		nb_stems <- length(stem_loc_sorted);
		//使用循环, 创建花序
		loop i from:0 to:nb_stems-1{
			create Stem number:1 returns: new_stem{							
				location <- stem_loc_sorted[i].location; 
				host_clone <- myself;
				//一级花序
				if (i = 0){
					inflorescence_position <- 1;
					//一级花开花所需要的的GDD  
					inflorescence_bloom_heat <- int(gauss(mean_gdd_primary, sd_gdd));
					inflorescence_berry_ripeness_heat <- int(gauss(mean_gdd_ripeness, sd_gdd_ripeness));
					//一级花序柱头花粉容纳上限是350
					stigma_capacity <- ovules_in_first_inflorescence;
					//二级花序保留6朵花
					nb_flowers_in_inflorescence <- 6;
					//创建一级花序上的6个花朵
					create Flower number:nb_flowers_in_inflorescence{		//初始化Flower
						//一级花胚珠数量是350
						nb_available_ovules <- ovules_in_first_inflorescence;
						nb_all_ovules<- ovules_in_first_inflorescence; 
					}
				}
				//一级花序
				else if(i = 1 or i = 2){
					inflorescence_position <- 2;
					//二级花开花所需要的的GDD   							
					inflorescence_bloom_heat <- int(gauss(mean_gdd_secondary, sd_gdd));
					inflorescence_berry_ripeness_heat <- int(gauss(mean_gdd_ripeness, sd_gdd_ripeness));
					//二级花序柱头花粉容纳上限是260
					stigma_capacity <- ovules_in_second_inflorescence;
					//二级花序保留3朵花
					nb_flowers_in_inflorescence <- 3;
					//创建二级花序上的3个花朵
					create Flower number:nb_flowers_in_inflorescence{		
						//二级花胚珠数量是350
						nb_available_ovules <- ovules_in_second_inflorescence;
						nb_all_ovules <- ovules_in_second_inflorescence;
					}
				}
				//三级花序
				else {
					inflorescence_position <- 3;   							
					//三级花开花所需要的的GDD 
					inflorescence_bloom_heat <- int(gauss(mean_gdd_secondary, sd_gdd));
					inflorescence_berry_ripeness_heat <- int(gauss(mean_gdd_ripeness, sd_gdd_ripeness));
					//三级花序柱头花粉容纳上限是350
					stigma_capacity <- ovules_in_second_inflorescence;
					//三级花序保留3朵花
					nb_flowers_in_inflorescence <- 3;
					//创建三级花序上的花朵
					create Flower number:nb_flowers_in_inflorescence{		
						nb_available_ovules <- ovules_in_third_inflorescence;
						nb_all_ovules <- ovules_in_third_inflorescence;
					}
				}			
			}
			list_stems <- list_stems union new_stem;
		}
		
		if(length(list_stems) >= nb_stems){
			has_stem <- true;
		}
	}	
	 
	//Update stem status on daily basis
	reflex stem_update when:current_julian > START_JULIAN and ((cycle - growth_start_on) mod cycle_per_day = 0){
		loop s over: list_stems{
			
				/*stem statistics update*/
				int nb_fertilized_flowers <- s.Flower count (each.fruit_mass>0);
				int nb_healthy_berries <- s.Flower count (each.fruit_mass>0);               //healthy_berries
				//畸形果数量，胚珠受孕率低于87%
				int nb_malformed_berries <- s.Flower count (  ((each.nb_achenes/each.nb_all_ovules)<0.87) and (each.fruit_mass>0)  );
				
				//Calculate the # of open flowers
				s.nb_open_flower <- (s.flower_state = 1)?s.nb_flowers_in_inflorescence:0;
				//Calculate pollen receptivity as the function of flower age
				//pollen_receptivity受到柱头和花粉活性的影响   
				//s.pollen_receptivity <- exp(-0.01 * s.flower_age^3);
				//experiment 888
				s.pollen_receptivity <- 0.74;          				         
				//s.nb_berries_stem <- s.Flower count (each.fruit_mass>0);
				s.nb_healthy_berries_stem <- nb_healthy_berries;
				s.nb_malformed_berries_stem <- nb_malformed_berries;
				
				s.yield_per_stem <- sum((s.Flower where (each.fruit_mass>0)) collect (each.fruit_mass));
				//s.fruit_set_per_stem <- (s.Flower count (each.fruit_mass>0 or each.fruit_mass=-2)) / (s.nb_flowers_in_inflorescence - s.Flower count (each.fruit_mass=-1));
				//fruit_set_per_stem表示座果率，从每个stem考虑
				s.fruit_set_per_stem <- nb_healthy_berries / s.nb_flowers_in_inflorescence;
				s.fruit_set_per_stem_II <- nb_fertilized_flowers / s.nb_flowers_in_inflorescence;
				s.avg_nb_seeds_per_stem <- mean((s.Flower where (each.fruit_mass>0)) collect (each.nb_accepted_pollen));
				s.avg_fruit_mass_per_stem <- mean((s.Flower where (each.fruit_mass>0)) collect (each.fruit_mass));			
				//s.avg_nb_accepted_pollen <- mean((s.Flower where (each.fruit_mass>0)) collect (each.nb_accepted_pollen));
				//s.avg_nb_received_pollen <- mean((s.Flower where (each.fruit_mass>0)) collect (each.nb_received_pollen));
				/*stem statistics update*/
								
				/*flower_state_transition*/
				if(s.flower_age < days_strawberry_bloom+1){
					//If the flower is in bud and the the GDD reaches the required bloom heat unit
					if(GDD > s.inflorescence_bloom_heat) and (s.flower_state = 0){     
						//Flower opening
						s.flower_state <- 1;
						s.inflorescence_bloom_day <- current_julian;
						flower_in_bloom <- true;
						if (bloom_day = 0){
							bloom_day <-current_julian;
						}
				
					}
					//If the flower is in bloom and its age less than days_strawberry_bloom
					if(s.flower_state = 1) and (s.flower_age < days_strawberry_bloom){
						//Increase flower age
						s.flower_age <- s.flower_age + 1;
					}
					//At the end of bloom
					if(s.flower_age = days_strawberry_bloom){
						s.flower_state <- 2;
						
						//Calculate probability of fertilization
						do fertilization_checking(s);							
																
						//No more this procedure
						s.flower_age <- days_strawberry_bloom+1;
					}								
				}
				//flower_state = 2，果实进入生长期，需要积累GDD以至成熟
				if (s.flower_state = 2 ){
					s.GDD_ripeness <- s.GDD_ripeness + max([(mean_daily_temperature - T_base_strawberry_for_ripeness), 0]);
					//write "GDD_ripeness:" + s.GDD_ripeness;
				}
				//进入成熟期
				if(s.GDD_ripeness > s.inflorescence_berry_ripeness_heat) and (s.flower_state = 2){     
					//Fruits ripen
					s.inflorescence_ripensess_day <-current_julian;
					s.flower_state <- 3;
					//write "current_julian"+current_julian+"inflorescence_ripensess_day:  "+s.inflorescence_ripensess_day;
				}	
				
				/*flower_state_transition*/		
				
				if(s.flower_state=1){
					//s.host_clone.in_bloom <- true;
					s.inflorescence_in_bloom <- true;
				}	
				else{
					//s.host_clone.in_bloom <- false;
					s.inflorescence_in_bloom <- false;
				}
		}
	}
	
		
	//Fertilization procedure
	action fertilization_checking (Stem xStem){	
 		loop f over: xStem.Flower{
 			//Calculate probability of fertilization as the function of the # of accepted pollen grains
 			//蓝莓中花朵的受孕率和nb_accepted_pollen是相关的
 			//草莓中假设只要接受花粉就受孕成功
 			f.nb_fertilized_ovules <- f.nb_accepted_pollen;
 			f.nb_achenes <- f.nb_fertilized_ovules;
 			bool whether_fertilized <- false;
 			if(f.nb_accepted_pollen > 0){
 				whether_fertilized <- true;
 			}			
 			//prob_fertilization <- prob_fertilization;		
 			//If the flower get fertilized
 			//if(flip(prob_fertilization)){
 			if(whether_fertilized){
 				//Calculate berry mass as the function of the # of accepted pollen grains
 				//草莓上瘦果和果实质量之间的关系，根据文献进行修改
 				//f.fruit_mass <- 1 - exp(-0.0182 * f.nb_accepted_pollen);
 				f.fruit_mass <- 0.05 * f.nb_achenes + 1.0;
 				//f.fruit_mass <- f.fruit_mass;
 			}	
 		}
 	}
 	
 	// Calculate the  required bloom heat unit from probability distribution
 	// 给每一个草莓植株赋予不同的自花适应概率
	action init_self_pollen_compatibility{
		 self_pollen_compatibility <- strawberry_self_compatibility_probability;
	}					
		
	aspect my_aspect {
		draw shape.contour color: simulation_started?°black:°white;
	}
}

//System scheduling
species SystemMonitor parallel:false use_regular_agents: false use_individual_shapes: false {	
	bool save_done_2 <- false;
	//Set honey bee hive
	action gen_honey_bees(int nb_bees){
		if(nb_bees > 0) {
			//At any place in bare ground
			//Or just the center of the field
			//point hive_location <- CENTER; 
			//Put all honey bee individuals into the same hive
			create Honeybee number:nb_bees{
				nest <- Hive_Location_Strawberry;
				location <- nest;
			}
		}
	}		
	
	//Create bees and their nests 
	action create_bee_population {
		do gen_honey_bees(nb_honybee_on_strawberry);		
	}	
	
	//Check whether clone initilization is done
	//检查草莓植株是否已经全部生成
	reflex check_strawberry_coverage when:!clone_init_done{
		if((StrawberryClone count (each.has_stem = true)) = length(StrawberryClone)){
			clone_init_done <- true;
			simulation_started <- true;
		    growth_start_on <- cycle;
		    //write "growth_start_on"+growth_start_on;		
			//Save current strawberry landscape into file
			//草莓地图不再保存			
			//save StrawberryClone to:"../includes/Strawberrylandscape.shp" type:"shp";		
			//Populate bee individuals for all taxa
			do create_bee_population();			
		}
		else{
			loop b over:StrawberryClone{
				ask b{
					do populate_stem();
				}
			}
		}		
	}

	//Change simulation cycles for each day
	reflex change_cycle_per_day when:simulation_started {
		//Detect if any flower is opening
		//flower_in_bloom <- (Stem count (each.flower_state=1)) > 0?true:false;
		//If has open flowers
		//9*60分钟，每分钟一次cycle
		if(bloom_day != 0 ){
			cycle_per_day <- int(540/minute_per_step);    //540cycle每日
		}
		else{
			cycle_per_day <- 1;
		}
	}
	
	//Output statistics on clone level when bloom season ends
	//每次cycle都更新费内存, 改成整点才更新
	reflex update_clone_indices  when:simulation_started and (is_clock or !flower_in_bloom){
	//reflex update_clone_indices  when:simulation_started{
	    //write "Day:"+current_julian+"  Time:"+time_8_to_17;
		loop i from:0 to:length(StrawberryClone) - 1{
				//草莓植株的ID，编号自动增加
				Clone_indices[i].clone_ID <- StrawberryClone[i].name;
				//每株草莓的占地面积，0.1*0.1*Pi
				Clone_indices[i].clone_size <- StrawberryClone[i].clone_area;
				//草莓的坐标
				Clone_indices[i].clone_location <- StrawberryClone[i].location;
				Clone_indices[i].clone_location_x <- StrawberryClone[i].location.x;
				Clone_indices[i].clone_location_y <- StrawberryClone[i].location.y;
				//该植株每个stem的平均蜜蜂访问量
				Clone_indices[i].clone_avg_beevisits_stem <- StrawberryClone[i].bee_density_counter/length(StrawberryClone[i].list_stems);
				//Clone_indices[i].clone_openflower_percentage <- (StrawberryClone[i].list_stems count (each.flower_state = 1)) / length(StrawberryClone[i].list_stems);	
				//植株的座果率，颜色根据fruit_set_per_stem计算
				//Clone_indices[i].clone_fruitset_mean <- mean(StrawberryClone[i].list_stems collect (each.fruit_set_per_stem));
				//☆植株的座果率需要考虑每个花序上花朵数量不同
				Clone_indices[i].clone_fruitset_mean <- (StrawberryClone[i].list_stems[0].fruit_set_per_stem*6+StrawberryClone[i].list_stems[1].fruit_set_per_stem*3+StrawberryClone[i].list_stems[2].fruit_set_per_stem*3)/12;
				Clone_indices[i].clone_fruitset_std <- standard_deviation(StrawberryClone[i].list_stems collect (each.fruit_set_per_stem));
				Clone_indices[i].clone_fruitsetII_mean <- mean(StrawberryClone[i].list_stems collect (each.fruit_set_per_stem_II));
				Clone_indices[i].clone_fruitsetII_std <- standard_deviation(StrawberryClone[i].list_stems collect (each.fruit_set_per_stem_II));
				//植株的果实总重量
				Clone_indices[i].clone_fruitmass_mean <- (sum(StrawberryClone[i].list_stems[0].Flower collect (each.fruit_mass))+sum(StrawberryClone[i].list_stems[1].Flower collect (each.fruit_mass))+sum(StrawberryClone[i].list_stems[2].Flower collect (each.fruit_mass)))/12;
				//Clone_indices[i].clone_fruitmass_mean <- mean(StrawberryClone[i].list_stems collect (each.avg_fruit_mass_per_stem));
				//Clone_indices[i].clone_fruitmass_std <- standard_deviation(StrawberryClone[i].list_stems collect (each.avg_fruit_mass_per_stem));
				//植株的平均种子(受孕胚珠、瘦果)数量
				Clone_indices[i].clone_seeds_mean <- mean(StrawberryClone[i].list_stems collect (each.avg_nb_seeds_per_stem));
				Clone_indices[i].clone_seeds_std <- standard_deviation(StrawberryClone[i].list_stems collect (each.avg_nb_seeds_per_stem));	
				//Clone_indices[i].clone_pollen_accepted <- mean(StrawberryClone[i].list_stems collect (each.avg_nb_accepted_pollen));
				//Clone_indices[i].clone_pollen_received <- mean(StrawberryClone[i].list_stems collect (each.avg_nb_received_pollen));
				//☆该植株的所有果实数量（包含畸形果）
				//Clone_indices[i].clone_healthy_berries <- mean(StrawberryClone[i].list_stems collect (each.nb_healthy_berries_stem));
				Clone_indices[i].clone_healthy_berries <- StrawberryClone[i].list_stems[0].nb_healthy_berries_stem+StrawberryClone[i].list_stems[1].nb_healthy_berries_stem+StrawberryClone[i].list_stems[2].nb_healthy_berries_stem;
				//该植株的畸形果数量
				Clone_indices[i].clone_malformed_berries <- StrawberryClone[i].list_stems[0].nb_malformed_berries_stem+StrawberryClone[i].list_stems[1].nb_malformed_berries_stem+StrawberryClone[i].list_stems[2].nb_malformed_berries_stem;
				//该植株的畸形果比率
				if(Clone_indices[i].clone_healthy_berries=0){
					//避免分母为0
					Clone_indices[i].clone_percent_malformed_berries <- 0.0;
				}
				else{
					Clone_indices[i].clone_percent_malformed_berries <-(Clone_indices[i].clone_malformed_berries)/(Clone_indices[i].clone_healthy_berries);
				}
				//多层读取每朵花的信息
				loop s from:0 to:2{
					loop f from:0 to:(StrawberryClone[i].list_stems[s].nb_flowers_in_inflorescence-1) {
						//给每一朵花标记序号
						int flower_nb <- -1;
						if(s=0){flower_nb <- 12*i + f;}
						if(s=1){flower_nb <- 12*i + 6 + f;}
						if(s=2){flower_nb <- 12*i + 9 + f;}
						//记录花朵的序号
						Flower_indices[flower_nb].Flower_ID <- flower_nb;
						//记录花朵所在的草莓植株序号
						Flower_indices[flower_nb].Flower_in_clone_ID <- i;
						//记录花朵的花序等级
						Flower_indices[flower_nb].Flower_in_inflorescence_ID <- (s=0)? 1:2;
						//记录每朵花对应的果实质量
						Flower_indices[flower_nb].Flower_fruit_mass<- StrawberryClone[i].list_stems[s].Flower[f].fruit_mass;
						//记录每朵花的开花时间，与花序保持一致
						Flower_indices[flower_nb].Flower_bloom_day   <- StrawberryClone[i].list_stems[s].inflorescence_bloom_day;
						//记录每朵花的果实成熟时间，与花序保持一致
						Flower_indices[flower_nb].Flower_ripeness_day <- StrawberryClone[i].list_stems[s].inflorescence_ripensess_day;
						//记录每朵花的蜜蜂访问次数，与花序保持一致
						Flower_indices[flower_nb].Flower_bee_visit <- StrawberryClone[i].list_stems[s].nb_bee_visit_stem;
						//记录每朵花来自同花和异花的花粉数量
						Flower_indices[flower_nb].Flower_nb_pollen_native <- StrawberryClone[i].list_stems[s].Flower[f].nb_pollen_native;
						Flower_indices[flower_nb].Flower_nb_pollen_foreign <- StrawberryClone[i].list_stems[s].Flower[f].nb_pollen_foreign;
						/* 
						if((i=1) and (s=2) and (f=1)){
							write "current_julian"+current_julian+"  "+StrawberryClone[i].list_stems[s].inflorescence_ripensess_day;
						}
						*/					
						
						//Flower_beery_malformed记录未生长的果实，状态标记为0
						if(StrawberryClone[i].list_stems[s].Flower[f].fruit_mass=0){
							Flower_indices[flower_nb].Flower_beery_malformed <-	0;
						}
						//记录畸形果，状态标记为1
						else if (((StrawberryClone[i].list_stems[s].Flower[f].nb_achenes/StrawberryClone[i].list_stems[s].Flower[f].nb_all_ovules)<0.87) and (StrawberryClone[i].list_stems[s].Flower[f].fruit_mass>0)){
							Flower_indices[flower_nb].Flower_beery_malformed <-	1;
						}
						//记录商业价值高的果实，标记为2
						else if (((StrawberryClone[i].list_stems[s].Flower[f].nb_achenes/StrawberryClone[i].list_stems[s].Flower[f].nb_all_ovules)>=0.87)){
							Flower_indices[flower_nb].Flower_beery_malformed <-	2;
						}																																																			
			        }   
			    }			
		}		
	}

	//Update some field attributes and output them on daily basis 
	reflex stat_field when:simulation_started{
		//总体开花率
		percent_flower_open<- (Stem count (each.flower_state=1))/length(Stem);
		//总体果实成熟率，只是错略的用于估计果实产量，不是精确的数值
		percent_fruits_ripeness <- (Stem count (each.flower_state=3))/length(Stem);
		//总体果实正在发育的比例
		percent_fruits_for_ripeness <- (Stem count (each.flower_state=2))/length(Stem);
		//总体座果率	
		percent_fruit_set <- mean(Clone_indices collect (each.clone_fruitset_mean));//mean(Stem collect (each.fruit_set_per_stem));
		percent_fruit_setII <- mean(Clone_indices collect (each.clone_fruitsetII_mean));//mean(Stem collect (each.fruit_set_per_stem));
		//总体畸形果率
		percent_malformed_berries <- mean(Clone_indices collect (each.clone_percent_malformed_berries));
		//平均草莓果实质量和方差
		avg_fruit_mass <- mean(Clone_indices collect (each.clone_fruitmass_mean));//mean(Stem collect (each.avg_fruit_mass_per_stem));
		sd_fruit_mass <- standard_deviation(Clone_indices collect (each.clone_fruitmass_mean));//standard_deviation(Stem collect (each.avg_fruit_mass_per_stem));
		//每个植株种子的数量
		avg_nb_seeds <- mean(Clone_indices collect (each.clone_seeds_mean));//mean(Stem collect (each.avg_nb_seeds_per_stem));
		sd_nb_seeds <- standard_deviation(Clone_indices collect (each.clone_seeds_mean));//standard_deviation(Stem collect (each.avg_nb_seeds_per_stem));
		//每株草莓平均果实数量
		avg_healthy_berries <- mean(Clone_indices collect (each.clone_healthy_berries));
		//草莓产量，kg/m2
		kg_yields_ha <- sum(Stem collect (each.yield_per_stem))/ (LANDSCAPE_SIZE_LENTH*LANDSCAPE_SIZE_WIDTH)/1000.0;
		//温室中飞行的蜜蜂数量
		nb_foraging_pollen <- Honeybee count ((each.bee_state = 1)or(each.bee_state = 2));

		//仿真结束时保存		
		if((current_julian = simulation_duration)and(!save_done_2)){
			//保存植株信息
			loop c over:Clone_indices{
				save[simID, repeatID, weather_path, 
					c.clone_ID, c.clone_size, c.clone_location_x, c.clone_location_y,c.clone_avg_beevisits_stem, c.clone_fruitset_mean, c.clone_fruitset_std, c.clone_fruitsetII_mean, c.clone_fruitsetII_std,
					c.clone_fruitmass_mean, c.clone_seeds_mean, c.clone_seeds_std, c.clone_healthy_berries, c.clone_malformed_berries,c.clone_percent_malformed_berries,c.clone_pollen_accepted, c.clone_pollen_received 
				] 
				to:"../output/"+simID+"_"+repeatID+"_Clone.csv" header:true type:"csv" rewrite:false; 
			}
			
			//保存仿真参数和重要结果
			save [simID, repeatID, 
				  LANDSCAPE_SIZE_LENTH, LANDSCAPE_SIZE_WIDTH, left_margin, top_margin,
				  nb_clones_column, nb_clones_row, hive_Location_X, hive_Location_Y,
				  nb_honybee_on_hive, ratio_bee_worker, honeybee_wordload, honeybee_max_travel_dist,
				  avg_fruit_mass,percent_malformed_berries
				]
				to:"../output/"+simID+"_"+repeatID+"_simulation_parameters_OnEnd.csv" header:true type:"csv" rewrite:false;
			
			//保存花朵信息
			loop f over:Flower_indices{
				save[simID, repeatID, weather_path, 
					 f.Flower_ID, f.Flower_in_clone_ID,f.Flower_in_inflorescence_ID,
					 f.Flower_bloom_day,f.Flower_ripeness_day,
					 f.Flower_fruit_mass,f.Flower_beery_malformed,f.Flower_bee_visit,f.Flower_nb_pollen_native,f.Flower_nb_pollen_foreign] 
				to:"../output/"+simID+"_"+repeatID+"_Flower.csv" header:true type:"csv" rewrite:false;
			}
				
			save_done_2 <- true;
		}
		
		//每日保存，保存的是温室总体的信息			
		if(simulation_started and (cycle - growth_start_on) mod cycle_per_day = 0) {
				save [simID, repeatID, weather_path, 
					current_julian, GDD, percent_flower_open, percent_fruits_ripeness,percent_fruit_set, percent_fruit_setII, percent_malformed_berries, avg_fruit_mass, avg_nb_seeds, avg_healthy_berries, kg_yields_ha
				] 
					to: (current_julian = (simulation_duration))?"../output/"+simID+"_"+repeatID+"_field_indicies_final.csv":"../output/"+simID+"_"+repeatID+"_field_indicies_EveryDay.csv" header:true type:"csv" rewrite:false;				
		}
	}	
}

//Run a single simulation
experiment GUI keep_seed: false type:gui {
	
	reflex halt_simulation{
		if(current_julian = simulation_duration){	
			ask simulation{
				/*Save data before quit simulation*/
				do pause();
			}
		}
	}
	output{
		
		display Simulation_Monitor {	
			graphics "Field" {
				if(!simulation_started){
					draw "Initializing..." color:°white at:{0.2,0.2};
				}
				else{
					if(show_screentext){
						draw "Current day: " + current_julian + ";  Cycle: " + cycle + "   Avg_fruit_mass:" + avg_fruit_mass + "   Bloom_day:"+bloom_day color:°black at:{0.2,0.2};
						draw "Time:" + time_8_to_17 + ":"+time_minute+ "    Activity:"+ honeybee_activity_ratio + "   Number:" + nb_foraging_pollen +"  percent_malformed_berries:"+percent_malformed_berries +"    Ripeness"+(percent_fruits_ripeness+percent_fruits_for_ripeness)  color:°black at:{0.2,0.4};
					}
				}
				
				draw shape.contour color:#white;
				draw field_boundary.contour  color:#black;
      			draw circle(0.3) at_location  Hive_Location_Strawberry color:#lightgray;
			}			
			species StrawberryClone transparency:0 aspect: my_aspect;
			species Stem transparency:0 aspect: my_aspect;		
			species Honeybee transparency:0 aspect: my_aspect;
		}
		 
		display DataPlot {
			chart "flower & fruit" type:xy style:exploded x_range:{START_JULIAN - 1, simulation_duration} y_range:{-2, 100} x_tick_unit:5 y_tick_unit:10 background: °white position: {0,0} size:{0.5,1} {
				data 'Julian'value:{current_julian,-5} color:°white;
				
				//data 'Blooming flower' value:{current_julian, percent_flower_open*100} legend:'Blooming flower (%)' color:°green ;
				data 'Blooming flower' value:{current_julian, percent_flower_open*100} legend:'Blooming flower (%)' color:°blue ;
				data 'Fruits Ripeness' value:{current_julian, percent_fruits_ripeness*100} legend:'Fruits Ripeness (%)' color:°pink ;
				data 'Fruit set'value:{current_julian, percent_fruit_set*100} legend:'Fruit set (%)' color:°red ;
				//展示总体果实平均质量
				//data 'Average fruit mass'value:{current_julian, avg_fruit_mass} legend:'Ave Fruit mass (g)' color:°purple ;
				//展示总体畸形果率
				//data "Percent_malformed_berries" value:{current_julian, percent_malformed_berries*100} legend:'Percent malformed berries (%)' color:°black ;
				//write "current_julian:" + current_julian + "     avg_fruit_mass:" + avg_fruit_mass;
				//data 'Average fruit mass'value:{current_julian, avg_fruit_mass*100} legend:'Ave Fruit mass (10mg)' color:°purple ;
				//data 'Average seeds number'value:{current_julian, avg_nb_seeds} legend:'Seeds number' color:°black ;
			}		
		}
		
		monitor "Current day:" value: current_julian;
		monitor "Avg fruit mass:" value: avg_fruit_mass;
		monitor "Malformed berries:" value: percent_malformed_berries;
		monitor "Cycle:" value: cycle;
		monitor "Time_hour:" value: time_8_to_17;
		monitor "Time_minute:" value: time_minute;
		monitor "Ripeness rate:" value: (percent_fruits_ripeness+percent_fruits_for_ripeness);
	}
}

experiment Monitor keep_seed: false type:gui {
	reflex halt_simulation{
		if(current_julian = simulation_duration){	
			ask simulation{
				do pause();
			}
		}
	}
	output{
		monitor "Current day:" value: current_julian;
		monitor "Avg fruit mass:" value: avg_fruit_mass;
		monitor "Malformed berries:" value: percent_malformed_berries;
		monitor "Cycle:" value: cycle;
		monitor "Time_hour:" value: time_8_to_17;
		monitor "Time_minute:" value: time_minute;
		monitor "Ripeness rate:" value: (percent_fruits_ripeness+percent_fruits_for_ripeness);
	}
}

//重复三次实验
/*
experiment Replicate type: gui{
	init {
		ask MainModel_model[0]{
				do die;
			}
		create MainModel_model with: [repeatID::1];
		create MainModel_model with: [repeatID::2];
	}
	
	reflex start_new_simulation2 when: simulation_done{
		
	}
	
	output{
		monitor "Current day:" value: current_julian;
		monitor "Avg fruit mass:" value: avg_fruit_mass;
		monitor "Malformed berries:" value: percent_malformed_berries;
		
	}
}
//
*/