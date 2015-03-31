classdef IOTestDriver < handle
    
    properties (SetAccess = private, GetAccess = private)
        vawg;
        configurationProvider;
        dac;
    end
    
    properties (SetAccess = private, GetAccess = public)
        expectedData = [];
        measuredData = [];
    end
    
    methods (Access = public)
        
        function obj = IOTestDriver(configurationProvider)
            if ~isa(configurationProvider, 'TestConfigurationProvider')
                error('IOTestDriver requires an instance of TestConfigurationProvider for parameter configurationProvider!');
            end
            obj.configurationProvider = configurationProvider;
        end
        
        function success = run(self)
            self.init();
            
            self.dac.startMeasurement(1);
            
            while self.vawg.isPlaybackInProgress()
                pause(1);
                fprintf('Waiting for playback to finish...\n');
            end

            self.measuredData = self.dac.getResult(1);
            
            success = self.evaluate();
        end
        
    end
    
    methods (Access = private)
        
        function init(self)
            % setup and arm awg
            self.initVAWG();            
            % obtain pulse group and expected data from test configuration
            self.configurationProvider.createPulseGroup();
            pulseGroup = self.configurationProvider.getPulseGroup();
            self.expectedData = self.configurationProvider.getExpectedData();
            
            % obtain DAC instance from test configuration
            self.dac = self.configurationProvider.createDAC();
            self.dac.useAsTriggerSource();
            
            
            self.vawg.add(pulseGroup.name);
            self.vawg.setActivePulseGroup(pulseGroup.name);
            self.vawg.arm();
        end
        
        function initVAWG(self)
            global vawg;
            
            self.vawg = VAWG();
            vawg = self.vawg;
            awg = PXDAC_DC('messrechnerDC', 1);
            awg.setOutputVoltage(1, 1.4);
            
            calllib('PXDAC4800_64','SetClockDivider1XD48',awg.handle,12);
            calllib('PXDAC4800_64','SetClockDivider2XD48',awg.handle,1);

            self.vawg.addAWG(awg);
            self.vawg.createVirtualChannel(awg, 1, 1);
        end
        
        function success = evaluate(self)
           err = self.measuredData' - self.expectedData; % error signal
           rms = std(err,0); % average error per sample
           maxerr = max(abs(err)); % maximum single error
           satisfiesMeanThreshold = rms < self.configurationProvider.getMeanErrorThreshold();
           satisfiesSingleThreshold = maxerr < self.configurationProvider.getSingleErrorThreshold();
           success = satisfiesMeanThreshold && satisfiesSingleThreshold; 
        end
        
    end
    
end

