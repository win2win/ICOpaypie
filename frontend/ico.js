"use strict";

var gasPrice, gasAmount, web3, Web3;



function init() {

    // Checks Web3 support
    if (typeof web3 !== 'undefined' && typeof Web3 !== 'undefined') {
        // If there's a web3 library loaded, then make your own web3
        web3 = new Web3(web3.currentProvider);
    } else if (typeof Web3 !== 'undefined') {
        // If there isn't then set a provider
        //var Method = require('./web3/methods/personal');
        web3 = new Web3(new Web3.providers.HttpProvider(connectionString));

        if (!web3.isConnected()) {

            $("#alert-danger-span").text(" Problem with connection to the newtwork. Please contact " + supportEmail + " abut it. ");
            $("#alert-danger").show();
            return;
        }
    } else if (typeof web3 == 'undefined' && typeof Web3 == 'undefined') {

        Web3 = require('web3');
        web3 = new Web3();
        web3.setProvider(new web3.providers.HttpProvider(onnectionString));
    }
    gasPrice = 20000000000;
    gasAmount = 4000000;

    retrieveData();
}


function retrieveData() {

    var blockEnd, startDate, endDate, tokenPrice;

  

    var ICOContradct = web3.eth.contract(ICOABI);
    var ICOHandle = ICOContradct.at(contractAddress);

    var durationInBlocks =  ICOHandle.endBlock() - ICOHandle.startBlock();

    // assumption is that 2.5 blocks will be created in one minute on averge
    var durationMinutes = Math.round(durationInBlocks / 2.5); 
    var startingTimeStamp = web3.eth.getBlock(ICOHandle.startBlock()).timestamp;
    var startDate = convertTimestamp(startingTimeStamp, false);
    var startDateObject = new Date(startDate);

    // add duration of campaign in minutes to determine the date of campaign end. 
    startDateObject.setMinutes (startDateObject.getMinutes() + durationMinutes);

    
    
   
    var numberOfContributors = Number(ICOHandle.numberOfBackers());
    var startingBlock = Number(ICOHandle.startBlock());
    
    var etherContributed = Number(ICOHandle.ETHReceived() / Math.pow(10, 18));
    var minCap = Number(ICOHandle.minCap()) / Math.pow(10, 10);
    var maxCap = Number(ICOHandle.maxCap()) / Math.pow(10, 10);
    var tokensSold = ICOHandle.PPPSentToETH()/ Math.pow(10,10);
    var tokenCurrentPrice = ICOHandle.tokenPriceWei() / Math.pow(10, 18);
    var contractStopped = ICOHandle.stopped();
    var minInvestmentEther = ICOHandle.minInvestETH() / Math.pow(10, 18);
    var tokensContractAddress = ICOHandle.ppp();


    $("#number-participants").html(formatNumber(numberOfContributors));
    $("#ico-start").html(new Date(convertTimestamp(startingTimeStamp,false)));
    $("#ico-end").html(startDateObject);
    $("#ether-raised").html(formatNumber(etherContributed) + " Eth");
    $("#tokens-sold").html(formatNumber(tokensSold) );
    $("#token-price").html(tokenCurrentPrice + " Eth");

    

    $("#min-cap").html(formatNumber(minCap));
    $("#max-cap").html(formatNumber(maxCap));
    


    //  }, 10);
}

function convertTimestamp(timestamp, onlyDate) {
    var d = new Date(timestamp * 1000),	// Convert the passed timestamp to milliseconds
        yyyy = d.getFullYear(),
        mm = ('0' + (d.getMonth() + 1)).slice(-2),	// Months are zero based. Add leading 0.
        dd = ('0' + d.getDate()).slice(-2),			// Add leading 0.
        hh = d.getHours(),
        h = hh,
        min = ('0' + d.getMinutes()).slice(-2),		// Add leading 0.
        sec = d.getSeconds(),
        ampm = 'AM',
        time;


    yyyy = ('' + yyyy).slice(-2);

    if (hh > 12) {
        h = hh - 12;
        ampm = 'PM';
    } else if (hh === 12) {
        h = 12;
        ampm = 'PM';
    } else if (hh == 0) {
        h = 12;
    }

    if (onlyDate) {
        time = mm + '/' + dd + '/' + yyyy;

    }
    else {
        // ie: 2013-02-18, 8:35 AM	
        time = yyyy + '-' + mm + '-' + dd + ', ' + h + ':' + min + ' ' + ampm;
        time = mm + '/' + dd + '/' + yyyy + '  ' + h + ':' + min + ':' + sec + ' ' + ampm;
    }

    return time;
}


function formatNumber(number) {
    number = number.toFixed(0) + '';
    var x = number.split('.');
    var x1 = x[0];
    var x2 = x.length > 1 ? '.' + x[1] : '';
    var rgx = /(\d+)(\d{3})/;
    while (rgx.test(x1)) {
        x1 = x1.replace(rgx, '$1' + ',' + '$2');
    }
    return x1 + x2;
}











