import pandas as pd
import numpy as np
import zarr

class ReadMLData_m1:
    def __init__(self, ds_path) -> None: #read data
        self.data = pd.read_csv(ds_path)
        #define static variables
        self.xs_vars = ['sum_exp_est_2_10', 'sum_anpp_2_10']
       
        #define dynamic variables
        self.xt_vars = [] 
        self.pft_list = ['BNE', 'IBS', 'TeBS', 'Tundra', 'otherC']
        
    def generate_ml_data(self, block_size):
        # ! Takes roughly 6 minutes
        set_uid = set(list(zip(self.data.Lat.values, self.data.Lon.values, self.data.PID.values)))
        num_samples = len(set_uid)
        x_t = np.zeros((num_samples, 100//block_size, len(self.xt_vars)))
        x_s = np.zeros((num_samples, len(self.xs_vars)))
        y_start = np.zeros((num_samples, 5)) #y here is PFT
        y_end = np.zeros((num_samples,5))
        y_block = np.zeros((num_samples, 100//block_size, 5))
        lat_lon_pid = np.zeros((num_samples,3) )

        for i, (lat, lon, pid) in enumerate(set_uid):   
            data_loc = self.data[(self.data["PID"]==pid) & (self.data["Lat"]==lat) & (self.data["Lon"]==lon)]

            data_loc = data_loc[data_loc["Year"]<data_loc["Year"].min()+100]
            if data_loc.shape == (500,24): #check if data makes sense
                x_t_loc = self.get_climate(data_loc=data_loc, block_size = block_size)
                y_end_loc = self.get_final_relative(data_loc=data_loc)
                y_start_loc = self.get_initial_relative(data_loc=data_loc)
                x_s_loc = self.get_states(data_loc=data_loc)
                y_block_loc = self.get_block_relative(data_loc=data_loc, block_size=block_size)
                

                if np.sum(y_end_loc)>1: #check 
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan

                elif np.sum(y_end_loc)<0.95:
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan      
                else:
                    assert np.max(y_start_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.max(y_end_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.min(y_start_loc) >= 0, f"Relative {y_end_loc} cannot be less than 0 "
                    
                    x_t[i] = x_t_loc
                    x_s[i] = x_s_loc
                    y_start[i] = y_start_loc
                    y_end[i] = y_end_loc
                    y_block[i] = y_block_loc
                    lat_lon_pid[i] = np.array([lat, lon, pid])


        return x_t, x_s, y_start, y_end, y_block, lat_lon_pid

                    
    def get_climate(self, data_loc, block_size):
        
        block_size=block_size

        assert 100%block_size==0
        t_len = 100//block_size

        x_t = np.zeros((t_len, len(self.xt_vars)))
        
        for i, var in enumerate(self.xt_vars):
            var_t = data_loc[data_loc.PFT == data_loc.PFT.unique()[0]].sort_values(by="Year")
            
            for j in range(t_len):
                val = getattr(var_t,var).values[block_size*j:block_size*(j+1)]
                x_t[j,i] = np.mean(val)
                
        return x_t

    def get_block_relative(self, data_loc, block_size):

        assert 100%block_size==0, "block should be divisible by 100 years"
        relative = np.zeros((100, 5))

        block_relative = np.zeros((100//block_size, 5))

        for i, pft in enumerate(data_loc.PFT.unique()): #get same PFT order
            relative[:,i] = data_loc[data_loc.PFT==pft].sort_values(by="Year").relative.values
        
        for i in range(100//block_size):
            block_relative[i, :] = np.mean(relative[block_size*i:block_size*(i+1), :], axis=0)

        return block_relative
    
    def get_final_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.max()].sort_values(by="PFT").relative.values
    
    def get_initial_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.min()].sort_values(by="PFT").relative.values
    
    def get_states(self, data_loc): 
        x_s = np.zeros((len(self.xs_vars)))

        for i, var in enumerate(self.xs_vars):
            data_loc = data_loc[data_loc.Year == data_loc.Year.min()]
            x_s[i] = getattr(data_loc, var).values[0]

        return x_s

class ReadMLData_m2:
    def __init__(self, ds_path) -> None: #read data
        self.data = pd.read_csv(ds_path)
        #define static variables
        self.xs_vars = []
       
        #define dynamic variables
        self.xt_vars = ["pr_yearlysum", "tas_gs_dailyavg", "tas_gs_dailymin", "tas_gs_dailymax", "rsds_gs_dailyavg"] 

        self.pft_list = ['BNE', 'IBS', 'TeBS', 'Tundra', 'otherC']
        
    def generate_ml_data(self, block_size):
        # ! Takes roughly 6 minutes
        set_uid = set(list(zip(self.data.Lat.values, self.data.Lon.values, self.data.PID.values)))
        num_samples = len(set_uid)
        x_t = np.zeros((num_samples, 100//block_size, len(self.xt_vars)))
        x_s = np.zeros((num_samples, len(self.xs_vars)))
        y_start = np.zeros((num_samples, 5)) #y here is PFT
        y_end = np.zeros((num_samples,5))
        y_block = np.zeros((num_samples, 100//block_size, 5))
        lat_lon_pid = np.zeros((num_samples,3) )

        for i, (lat, lon, pid) in enumerate(set_uid):   
            data_loc = self.data[(self.data["PID"]==pid) & (self.data["Lat"]==lat) & (self.data["Lon"]==lon)]

            data_loc = data_loc[data_loc["Year"]<data_loc["Year"].min()+100]
            if data_loc.shape == (500,24): #check if data makes sense
                x_t_loc = self.get_climate(data_loc=data_loc, block_size = block_size)
                y_end_loc = self.get_final_relative(data_loc=data_loc)
                y_start_loc = self.get_initial_relative(data_loc=data_loc)
                x_s_loc = self.get_states(data_loc=data_loc)
                y_block_loc = self.get_block_relative(data_loc=data_loc, block_size=block_size)
                

                if np.sum(y_end_loc)>1: #check 
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan

                elif np.sum(y_end_loc)<0.95:
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan      
                else:
                    assert np.max(y_start_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.max(y_end_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.min(y_start_loc) >= 0, f"Relative {y_end_loc} cannot be less than 0 "
                    
                    x_t[i] = x_t_loc
                    x_s[i] = x_s_loc
                    y_start[i] = y_start_loc
                    y_end[i] = y_end_loc
                    y_block[i] = y_block_loc
                    lat_lon_pid[i] = np.array([lat, lon, pid])


        return x_t, x_s, y_start, y_end, y_block, lat_lon_pid

                    
    def get_climate(self, data_loc, block_size):
        
        block_size=block_size

        assert 100%block_size==0
        t_len = 100//block_size

        x_t = np.zeros((t_len, len(self.xt_vars)))
        
        for i, var in enumerate(self.xt_vars):
            var_t = data_loc[data_loc.PFT == data_loc.PFT.unique()[0]].sort_values(by="Year")
            
            for j in range(t_len):
                val = getattr(var_t,var).values[block_size*j:block_size*(j+1)]
                x_t[j,i] = np.mean(val)
                
        return x_t

    def get_block_relative(self, data_loc, block_size):

        assert 100%block_size==0, "block should be divisible by 100 years"
        relative = np.zeros((100, 5))

        block_relative = np.zeros((100//block_size, 5))

        for i, pft in enumerate(data_loc.PFT.unique()): #get same PFT order
            relative[:,i] = data_loc[data_loc.PFT==pft].sort_values(by="Year").relative.values
        
        for i in range(100//block_size):
            block_relative[i, :] = np.mean(relative[block_size*i:block_size*(i+1), :], axis=0)

        return block_relative
    
    def get_final_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.max()].sort_values(by="PFT").relative.values
    
    def get_initial_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.min()].sort_values(by="PFT").relative.values
    
    def get_states(self, data_loc): 
        x_s = np.zeros((len(self.xs_vars)))

        for i, var in enumerate(self.xs_vars):
            data_loc = data_loc[data_loc.Year == data_loc.Year.min()]
            x_s[i] = getattr(data_loc, var).values[0]

        return x_s


class ReadMLData_m3:
    def __init__(self, ds_path) -> None: #read data
        self.data = pd.read_csv(ds_path)
        #define static variables
        self.xs_vars = ['bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon']
       
        #define dynamic variables
        self.xt_vars = [] 

        self.pft_list = ['BNE', 'IBS', 'TeBS', 'Tundra', 'otherC']
        
    def generate_ml_data(self, block_size):
        # ! Takes roughly 6 minutes
        set_uid = set(list(zip(self.data.Lat.values, self.data.Lon.values, self.data.PID.values)))
        num_samples = len(set_uid)
        x_t = np.zeros((num_samples, 100//block_size, len(self.xt_vars)))
        x_s = np.zeros((num_samples, len(self.xs_vars)))
        y_start = np.zeros((num_samples, 5)) #y here is PFT
        y_end = np.zeros((num_samples,5))
        y_block = np.zeros((num_samples, 100//block_size, 5))
        lat_lon_pid = np.zeros((num_samples,3) )

        for i, (lat, lon, pid) in enumerate(set_uid):   
            data_loc = self.data[(self.data["PID"]==pid) & (self.data["Lat"]==lat) & (self.data["Lon"]==lon)]

            data_loc = data_loc[data_loc["Year"]<data_loc["Year"].min()+100]
            if data_loc.shape == (500,24): #check if data makes sense
                x_t_loc = self.get_climate(data_loc=data_loc, block_size = block_size)
                y_end_loc = self.get_final_relative(data_loc=data_loc)
                y_start_loc = self.get_initial_relative(data_loc=data_loc)
                x_s_loc = self.get_states(data_loc=data_loc)
                y_block_loc = self.get_block_relative(data_loc=data_loc, block_size=block_size)
                

                if np.sum(y_end_loc)>1: #check 
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan

                elif np.sum(y_end_loc)<0.95:
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan      
                else:
                    assert np.max(y_start_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.max(y_end_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.min(y_start_loc) >= 0, f"Relative {y_end_loc} cannot be less than 0 "
                    
                    x_t[i] = x_t_loc
                    x_s[i] = x_s_loc
                    y_start[i] = y_start_loc
                    y_end[i] = y_end_loc
                    y_block[i] = y_block_loc
                    lat_lon_pid[i] = np.array([lat, lon, pid])


        return x_t, x_s, y_start, y_end, y_block, lat_lon_pid

                    
    def get_climate(self, data_loc, block_size):
        
        block_size=block_size

        assert 100%block_size==0
        t_len = 100//block_size

        x_t = np.zeros((t_len, len(self.xt_vars)))
        
        for i, var in enumerate(self.xt_vars):
            var_t = data_loc[data_loc.PFT == data_loc.PFT.unique()[0]].sort_values(by="Year")
            
            for j in range(t_len):
                val = getattr(var_t,var).values[block_size*j:block_size*(j+1)]
                x_t[j,i] = np.mean(val)
                
        return x_t

    def get_block_relative(self, data_loc, block_size):

        assert 100%block_size==0, "block should be divisible by 100 years"
        relative = np.zeros((100, 5))

        block_relative = np.zeros((100//block_size, 5))

        for i, pft in enumerate(data_loc.PFT.unique()): #get same PFT order
            relative[:,i] = data_loc[data_loc.PFT==pft].sort_values(by="Year").relative.values
        
        for i in range(100//block_size):
            block_relative[i, :] = np.mean(relative[block_size*i:block_size*(i+1), :], axis=0)

        return block_relative
    
    def get_final_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.max()].sort_values(by="PFT").relative.values
    
    def get_initial_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.min()].sort_values(by="PFT").relative.values
    
    def get_states(self, data_loc): 
        x_s = np.zeros((len(self.xs_vars)))

        for i, var in enumerate(self.xs_vars):
            data_loc = data_loc[data_loc.Year == data_loc.Year.min()]
            x_s[i] = getattr(data_loc, var).values[0]

        return x_s


class ReadMLData_m4:
    def __init__(self, ds_path) -> None: #read data
        self.data = pd.read_csv(ds_path)
        #define static variables
        self.xs_vars = ['bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                        'sum_exp_est_2_10', 'sum_anpp_2_10']
       
        #define dynamic variables
        self.xt_vars = ["pr_yearlysum", "tas_gs_dailyavg", "tas_gs_dailymin", "tas_gs_dailymax", "rsds_gs_dailyavg"]

        self.pft_list = ['BNE', 'IBS', 'TeBS', 'Tundra', 'otherC']
        
    def generate_ml_data(self, block_size):
        # ! Takes roughly 6 minutes
        set_uid = set(list(zip(self.data.Lat.values, self.data.Lon.values, self.data.PID.values)))
        num_samples = len(set_uid)
        x_t = np.zeros((num_samples, 100//block_size, len(self.xt_vars)))
        x_s = np.zeros((num_samples, len(self.xs_vars)))
        y_start = np.zeros((num_samples, 5)) #y here is PFT
        y_end = np.zeros((num_samples,5))
        y_block = np.zeros((num_samples, 100//block_size, 5))
        lat_lon_pid = np.zeros((num_samples,3) )

        for i, (lat, lon, pid) in enumerate(set_uid):   
            data_loc = self.data[(self.data["PID"]==pid) & (self.data["Lat"]==lat) & (self.data["Lon"]==lon)]

            data_loc = data_loc[data_loc["Year"]<data_loc["Year"].min()+100]
            if data_loc.shape == (500,24): #check if data makes sense
                x_t_loc = self.get_climate(data_loc=data_loc, block_size = block_size)
                y_end_loc = self.get_final_relative(data_loc=data_loc)
                y_start_loc = self.get_initial_relative(data_loc=data_loc)
                x_s_loc = self.get_states(data_loc=data_loc)
                y_block_loc = self.get_block_relative(data_loc=data_loc, block_size=block_size)
                

                if np.sum(y_end_loc)>1: #check 
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan

                elif np.sum(y_end_loc)<0.95:
                    x_t[i] =np.nan
                    x_s[i] = np.nan
                    y_start[i] = np.nan
                    y_end[i] = np.nan
                    y_block[i] = np.nan
                    lat_lon_pid[i] = np.nan      
                else:
                    assert np.max(y_start_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.max(y_end_loc) <= 1.0, f"Relative {y_end_loc} cannot be larger than 1 "
                    assert np.min(y_start_loc) >= 0, f"Relative {y_end_loc} cannot be less than 0 "
                    
                    x_t[i] = x_t_loc
                    x_s[i] = x_s_loc
                    y_start[i] = y_start_loc
                    y_end[i] = y_end_loc
                    y_block[i] = y_block_loc
                    lat_lon_pid[i] = np.array([lat, lon, pid])


        return x_t, x_s, y_start, y_end, y_block, lat_lon_pid

                    
    def get_climate(self, data_loc, block_size):
        
        block_size=block_size

        assert 100%block_size==0
        t_len = 100//block_size

        x_t = np.zeros((t_len, len(self.xt_vars)))
        
        for i, var in enumerate(self.xt_vars):
            var_t = data_loc[data_loc.PFT == data_loc.PFT.unique()[0]].sort_values(by="Year")
            
            for j in range(t_len):
                val = getattr(var_t,var).values[block_size*j:block_size*(j+1)]
                x_t[j,i] = np.mean(val)
                
        return x_t

    def get_block_relative(self, data_loc, block_size):

        assert 100%block_size==0, "block should be divisible by 100 years"
        relative = np.zeros((100, 5))

        block_relative = np.zeros((100//block_size, 5))

        for i, pft in enumerate(data_loc.PFT.unique()): #get same PFT order
            relative[:,i] = data_loc[data_loc.PFT==pft].sort_values(by="Year").relative.values
        
        for i in range(100//block_size):
            block_relative[i, :] = np.mean(relative[block_size*i:block_size*(i+1), :], axis=0)

        return block_relative
    
    def get_final_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.max()].sort_values(by="PFT").relative.values
    
    def get_initial_relative(self, data_loc):
        return data_loc[data_loc.Year==data_loc.Year.min()].sort_values(by="PFT").relative.values
    
    def get_states(self, data_loc): 
        x_s = np.zeros((len(self.xs_vars)))

        for i, var in enumerate(self.xs_vars):
            data_loc = data_loc[data_loc.Year == data_loc.Year.min()]
            x_s[i] = getattr(data_loc, var).values[0]

        return x_s


class FOREData:
    def __init__(self, ds_path):
        print(ds_path)
        self.ds_path = ds_path
        print(self.ds_path)

    def data(self,):
        with zarr.open(self.ds_path, "r") as f:
            x_t = f["x_t"][:]
            x_s = f["x_s"][:]
            y_start = f["y_start"][:]
            y_end = f["y_end"][:]
            y_block = f["y_block"][:]
            lat_lon_pid = f["lat_lon_pid"][:]

        return x_t, x_s, y_start, y_end, y_block, lat_lon_pid

    
