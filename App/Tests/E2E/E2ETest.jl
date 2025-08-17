# TODO: Fix E2E Tests

include("FileComparator.jl")
include("../BenchmarkTimes.jl")
using Test
using HTTP
using JSON
using Base
using BenchmarkTools
using .FileComparator

url = "http://localhost:5004"

function make_get_request(url)
    response = HTTP.get(url)
    return response
end

function make_post_request(url, json_data)
    headers = ["Content-Type" => "application/json"]

    # Convert the data to JSON string if it's not already
    body = json_data

    response = HTTP.post(url, headers, body)
    return response
end

function compare_file_with_response(
    response_data_path::String, expected_data_path::String, response_json::Any
)
    @test isfile(response_data_path)
    expected_response = JSON.parse(read(expected_data_path, String))
    @test response_json == expected_response
end

@testset "E2E Small Strategy Test" begin
    # Read and parse the JSON file
    json_path = "./App/Tests/E2E/JSONs/SmallStrategy.json"
    json_data = read(json_path, String)

    # Make the POST request
    backtest_url = "http://localhost:5004/backtest"
    response = make_post_request(backtest_url, json_data)
    response_json = JSON.parse(String(response.body))
    @test response.status == 200
    @test isdir("./App/Cache/d2936843a0ad3275a5f5e72749594ffe")
    @test compare_cache_files(
        "./App/Tests/E2E/ExpectedFiles/SmallStrategy.json",
        "./App/Cache/d2936843a0ad3275a5f5e72749594ffe/d2936843a0ad3275a5f5e72749594ffe.json",
        "2024-01-02",
    )

    @test isdir("./App/SubtreeCache")
    subtree_cache_hashes = [
        "2511ec40670864a5df3291f137f8f5c7"
        "7457fea7ea524c71fda4053459977a7e"
        "ddd84df46214783f11e60e928760cd18"
    ]
    for hash in subtree_cache_hashes
        @test compare_subtree_cache_files(
            hash, length(response_json["dates"]), "2024-01-02"
        )
    end

    # timing_data = @benchmark compare_cache_files(
    #     "./App/Tests/E2E/ExpectedFiles/SmallStrategy.json",
    #     "./App/Cache/d2936843a0ad3275a5f5e72749594ffe/d2936843a0ad3275a5f5e72749594ffe.json",
    #     "2024-01-02",
    # )
    # min_time = minimum(timing_data).time * 1e-9
    # # range = get_range(MIN_COMPARE_CACHE_FILES_SMALL_STRATEGY)
    # # @test MIN_COMPARE_CACHE_FILES_SMALL_STRATEGY - range <= min_time <= MIN_COMPARE_CACHE_FILES_SMALL_STRATEGY + range
    # println("Minimum time taken for compare_cache_files with small strategy: ", min_time, " seconds")

    # timing_data = @benchmark compare_subtree_cache_files(
    #     hash, length(response_json["dates"]), "2024-01-02"
    # )
    # min_time = minimum(timing_data).time * 1e-9
    # # range = get_range(MIN_COMPARE_SUBTREE_CACHE_FILES_SMALL_STRATEGY)
    # # @test MIN_COMPARE_SUBTREE_CACHE_FILES_SMALL_STRATEGY - range <= min_time <= MIN_COMPARE_SUBTREE_CACHE_FILES_SMALL_STRATEGY + range
    # println("Minimum time taken for compare_subtree_cache_files with small strategy: ", min_time, " seconds")

    # Clean up
    # delete Cache/, SubtreeCache/ and IndicatorData/
    rm("./App/Cache"; force=true, recursive=true)
    for file in readdir("./App/SubtreeCache/")
        rm(joinpath("./App/SubtreeCache/", file); force=true, recursive=true)
    end
    rm("./App/IndicatorData"; force=true, recursive=true)
end

# @testset "E2E Medium Strategy Test" begin
#     # Read and parse the JSON file
#     json_path = "./App/Tests/E2E/JSONs/MediumStrategy.json"
#     json_data = read(json_path, String)

#     # Make the POST request
#     backtest_url = "http://localhost:5004/backtest"
#     response = make_post_request(backtest_url, json_data)
#     response_json = JSON.parse(String(response.body))
#     @test response.status == 200
#     @test isdir("./App/Cache/ab01ee6d46b9233a7df7309b0e92916f")
#     @test compare_cache_files(
#         "./App/Tests/E2E/ExpectedFiles/MediumStrategy.json",
#         "./App/Cache/ab01ee6d46b9233a7df7309b0e92916f/ab01ee6d46b9233a7df7309b0e92916f.json",
#         "2024-01-02",
#     )

#     @test isdir("./App/SubtreeCache")
#     subtree_cache_hashes = [
#         "02d18b804efd1f9dd1409a2fb744ada7",
#         "0509d1d6a23e62ab63f3cee4377c4a0e",
#         "08185bd374382add7b17ceb3a7645fd8",
#         "0a79e496f02bc2a410a2c0d59caceb40",
#         "0d2bcb536b8d7c36ff3309c79dd53694",
#         "10f656bf93882b0973b53ef747bc56d3",
#         "11493115d47f1ed5fde1f1689a90254a",
#         "168dfc5a0593424066d979479497692d",
#         "1a825a1927f36973c64194e222b7347f",
#         "1d575022a57c838a8ef8bb97a0de95c5",
#         "1d6dda66323dba9407d99a94b25e5c79",
#         "206875cf99fe5d652cacdf4bc6ac9822",
#         "290dd5bf7e3e64acc3a8387fb7029d91",
#         "2ab2cc3c02bd7e54d8bb5b808510ecaa",
#         "2ed1307567c009bb7ec423d3f189bf70",
#         "310d638b1de1ba4253bc07db641ce781",
#         "346bad95c3b3033ffc7fc7db76dd3eed",
#         "36d27260b3d3c3cc5aaf08ff2a09812c",
#         "3bc925d0b437fbfa82cdaa31bc1ff4c1",
#         "3d374900710e9f280da3f0ad79a4db98",
#         "40197b3e74f47a0652dd8a00baa79255",
#         "40f528d4337649c6c2ea93ba3394b0c4",
#         "44c1cb4568b3eb3828adc7e4cbb4bcf9",
#         "46068d705c2bdd35135e9effd7cff70e",
#         "4907206104ec1a5f2edc1d47a63c2745",
#         "5097a2e0bcf9bf353a05e879645e0d42",
#         "5122877428effec03711a2c83a8eb28a",
#         "5912f1f8e539ac854c5a432ce83d037d",
#         "59ce7a5a0802857f91d159965664d5e1",
#         "5e560af5e3ede31c3b40df40e32e6670",
#         "74fd645e46e9ee5bcd134be10f265981",
#         "756c698bdeb64202bfba1674be42d25f",
#         "77277b6786f4a71e0a7d317d82515217",
#         "7883a0c86c0d348948eff7c01bfbc388",
#         "7a4a8686ead0df34a9e08134a0fac06f",
#         "7a851ad6002d688e4cbb706169d510bf",
#         "7f5d1c8e6bc8d1c4d895758f63b9137b",
#         "84032d8eed0ee5f76db273632d0dde31",
#         "88026064ce9d5e31fbe071d9a8d3374d",
#         "8b244e0ae9a732b6d61af07ce16ecd30",
#         "8d2f664c3dcb17a88c4fec1e66e21c1f",
#         "9424846129fa71b0c812c428da076c2c",
#         "953b1f1c0ac6503ef320045f82fcd387",
#         "978bd86ffdc9706bc56638dc288bff51",
#         "a2c97c360c7d3320d3c401ae9e48e24d",
#         "a4466276aaff24ab7ee63f6252ed2b4c",
#         "a4c74f33b0e0d1be6f03d0debd4289cf",
#         "ab7a6b17d184a2c60caf95b079132c93",
#         "ad23075d6285ff021ea4e9a2ccf13f9b",
#         "b81e6f1c1ffba2cb6c7c99244dde5ec5",
#         "c565c9ca0e10bb4b5fb408672637f937",
#         "c8be83cb914484b02185d8348150ebe4",
#         "cc34c83c0159d9dfcc52f2d8b70f6fa7",
#         "cd1bcb974da7bfe237089abf2105cf18",
#         "d81e2948407e15a6206f19921eeaa6df",
#         "dc811cbaa210c024c1f9de498082d330",
#         "dd2ba7a5534195702f7b6aba597694b9",
#         "e4709b7baaf5d48f67f3580f8eeaab77",
#         "e6778fc3f503cea45894b06a0ddd4304",
#         "eca228db372466f8676366a5bc1497c1",
#         "ee060866f3f053e7cfdf23208ada62d8",
#         "fca6e71664f32829b0678ac4d8bfbb4d",
#     ]
#     for hash in subtree_cache_hashes
#         @test compare_subtree_cache_files(
#             hash, length(response_json["dates"]), "2024-01-02"
#         )
#     end

#     # Clean up
#     rm("./App/Cache"; force=true, recursive=true)
#     for file in readdir("./App/SubtreeCache/")
#         rm(joinpath("./App/SubtreeCache/", file); force=true, recursive=true)
#     end
#     rm("./App/IndicatorData"; force=true, recursive=true)
# end

# @testset "E2E Large Strategy Test" begin
#     # Read and parse the JSON file
#     json_path = "./App/Tests/E2E/JSONs/LargeStrategy.json"
#     json_data = read(json_path, String)

#     # Make the POST request
#     backtest_url = "http://localhost:5004/backtest"
#     response = make_post_request(backtest_url, json_data)
#     response_json = JSON.parse(String(response.body))
#     @test response.status == 200
#     @test isdir("./App/Cache/1de964f1f86c0113088fbd8d3bb09c5e")
#     @test compare_cache_files(
#         "./App/Tests/E2E/ExpectedFiles/LargeStrategy.json",
#         "./App/Cache/1de964f1f86c0113088fbd8d3bb09c5e/1de964f1f86c0113088fbd8d3bb09c5e.json",
#         "2024-01-02",
#     )

#     @test isdir("./App/SubtreeCache")
#     subtree_cache_hashes = [
#         "002468647771cbd586b7c8dfd6c281a8",
#         "00985e0af5f9ca9d62b040335a318140",
#         "01262797149e9ebf63ab06ec808161c3",
#         "018a4bf6e161c596f0eef0af23c80d56",
#         "01938e863d9755d2bfa4ba9854f5fc2f",
#         "01c52003b336ee92ccd6b59fec9be43f",
#         "02db1ffa74585bde7f7751dca9206286",
#         "035a5c6779458d5816244e5b5a759a2e",
#         "036d2e06bee7b1ccbf84b4a5354beb80",
#         "0401a14d77078204b1435806fa37fe56",
#         "04fdda74b15aa7f16e151d2571a6ec87",
#         "05947e72f4f3d000ea92225f353b1e04",
#         "0601db295b260d3cff557f50fa98cad0",
#         "067b81b177b707bdd70860eb39893065",
#         "08a5b944e000d398b61c824e1b9c5775",
#         "08b5023b98ba156925548829aea7384c",
#         "090967fb3b6dc9e7ef081e13e6774016",
#         "09e5ed2e9784a8104d8cf9c43d1c49bb",
#         "09f927ab27d7c29adf363a98ba76996c",
#         "0ad4f496a1417c5d0aebb7ee2ae697ed",
#         "0b4c1500414bb6813985fc65896914d7",
#         "0b4ff9f9beb05f09e9fecb28e49d7725",
#         "0c90a7a73d8faa7c8085d6af2e6393d0",
#         "0cdfc6a59b61c2459952744a935b6151",
#         "0d683f012abb718534f4ea936b44bd97",
#         "0df93cd06f644a746ba7568f3e083a81",
#         "0e18951d328db84c1b5141cfbac7dde9",
#         "0e3638d6d109cf75074df0923f0b4482",
#         "0e3e4a866d7a5c25f86683f65889a38a",
#         "0e6f1eab2c13c7ab9c768f98e7eb17a5",
#         "0f5be6ffd79f7e98e9c24713afb61f1b",
#         "1005b436555c237451412d13239e0694",
#         "10e8545fb14fb2b25493234eded3f655",
#         "116d4b08e06aa26514dc35c061a9d984",
#         "1240961eb7070169edf7faf58203b831",
#         "12894355c7243cb5076682973cdf61ae",
#         "138e128ea2be2c9e354fc951b180b7d6",
#         "13c0eb4f2c92685fc052a9b0903d1128",
#         "13e7f62fafb2bbad37e06ac253d0eb00",
#         "150e1da0d1febd7ac271663b1a453a4a",
#         "1556a1d3bbefb0a6bfcf650bc73f8a2a",
#         "15c2262b36b1558f6b97148ea61b081d",
#         "161b5f2d96654199d29b17a5289e673e",
#         "16debc6c08bf1b66df0a017d6f6296e1",
#         "1711ff88ab15c6d34ab3dbd8e5aff717",
#         "17777e890e11a075150ea9a804eda960",
#         "17fa19a44ffb11b133413d6adb920e98",
#         "18990f520a1f9aad78c48c3e6128df13",
#         "1a354cb7806864b446ea074f19f91043",
#         "1b315a13cf38a7fcbccb8d9d1b4dccd1",
#         "1bebcb534f3f8163e9aeeaab596b539c",
#         "1c41d7e29e73c6fc8f3a65140cae9b6f",
#         "1c80d1a638c624b11993f6c6b4b3dd8f",
#         "1e390789c99838aa4d09cf48f8487c9b",
#         "1e5a9dae536d98d9d99da0f8d2cac065",
#         "1fa15073a7848aead6569faaf56b0f29",
#         "21aae178c17e48e4711be4db94b2b092",
#         "220f5674f12e2022d7d741c2aec93003",
#         "2224754a3a9722295b6ca21cc637cd33",
#         "22e4e4b36dbabbaaa81edbe8a51ed0ec",
#         "2318a9ef345f0e5541ae6e49c0d669bd",
#         "2341f4c8685ae8d35e792a3087f37786",
#         "24a06f587be13139aa5dca9cf0ba1a95",
#         "2574d47f5a1d53a275a78d5b6ff5eea2",
#         "2607ae42e83ee34c687e9d3d8207523a",
#         "28236663bcbd2802c125cd39fd23bd4c",
#         "2869a72845ff492e8e97a3879f7d0e5f",
#         "286a05271c9528680e2b83caf2946ec2",
#         "2a9846ce4cdb80806fc3645629d3ac2d",
#         "2b3569cd0045770e8f040d20d89b474c",
#         "2bc4099457cf2b687f78777f9be596bf",
#         "2d7157ae26b4226f93f7f90e2f1dac8f",
#         "2d89e224f0a9e8a1119bc1b0fbd3759d",
#         "2e37d1b2003ed2a938a796e1da4bc1ac",
#         "2eb9f96ae2952e1499d43d83d7f7160d",
#         "2f481749dc090b9635c35c12197510a2",
#         "3011e4d863c2675b1e34e72b9465aeb6",
#         "3123d636e2ae7ca043dfd249d3433ee5",
#         "3218a2aa62ad794701ba9d6ae9b298b5",
#         "334d076e2c242c308285cfe18095888f",
#         "33a79c26080f18e27be44ad8fa4bd445",
#         "33eaa9720aba7c51481c27b8628c50d6",
#         "344baee35894d9090904156502e60b6f",
#         "348042ece5cfd3b8bdffe9f324b52c2d",
#         "34e3370ce2bc79a06cfec2bf1f27d92f",
#         "34ea075d0fb69ab2091c565c8096d629",
#         "358c00884d41bc21b887957449d63e4c",
#         "358eb14591e1a3dafe2d2454ebff83f8",
#         "3650d13507381f1c6136129e32bacdd3",
#         "36c7e088081075475d823edcee0619b8",
#         "37a0ebb97d778581c7e40fadabb69a1d",
#         "38cc7f7e1ba3a19926131392d767127f",
#         "391dfeb78a5ab3e32f71286f2c4918c2",
#         "3946b352b8d8b7a40cc46f210ee7967c",
#         "39da6912feb1b677227cd2aad9811705",
#         "3a1fd705ac9ac887fce3672bd40b4486",
#         "3cadbc4529757385c268c0e488ea33f0",
#         "3e209dd89aa9e57ac649ada7d611dbcc",
#         "3ec5b9fa9d6d3da5c0218033983abe8b",
#         "3f28ac77d7890dfffa5fb8ab93251c58",
#         "3fc51727d3731da206eafda0f89b5e5a",
#         "3ff34156a33635cf07b5050502e07880",
#         "40ee2bbb1710580aa240a107f02967df",
#         "417df36efa65fa7a8a4a39593f845147",
#         "41a905f7f757152d2d20a1be3a182917",
#         "41b698092cb88c3fcacd328845ca6298",
#         "41e292ded758e2ac5cebfc8daf368c27",
#         "41efef8e1121d4888d2b6926a5e10eeb",
#         "422700aeef692bb8e0f56457510a526c",
#         "42c28d3b97a4e8511792b9d907ff8bc1",
#         "42cab4d6368db64cf48263e9d64331b7",
#         "42e6a6403d44def32188cb9d43365c93",
#         "43db758be08f23866d92b2425525e343",
#         "43ebe5a2a2ad3bd14f306c88db55194b",
#         "4458950b41d7fd68d345db41b2874765",
#         "445b602f20087a6f34a2f653a8751bd8",
#         "44e021c0678e6fb91beadc45cb6e5240",
#         "44e4f36fd25eebc45728c2d8be2c7e58",
#         "45279fa98b6fd391d23b9bb99a7d8a08",
#         "475d2dfc8e4657afa68ec78af5774af5",
#         "4862adcd887c80e2060ef55a193673e7",
#         "488c5b12edc2cce8eb010753a7a09700",
#         "49328dd3d709dd054131aeb5d6c341e1",
#         "49462c2cb7527a68497dfd1521c96f80",
#         "49510f5c96b4df50615375342d1d71e3",
#         "49653a591a5eb9e70cc2191a56e9e519",
#         "4a2b90b69eaa8bc29894d3660485ba34",
#         "4a7ed01e3f0f709136472fe292ba7e42",
#         "4b7decece587d0ec6fd790102987b99d",
#         "4c8d63aa20c33b75cfcab96a98c3df39",
#         "4d694d6511d87fc60232e43d2ef4ff20",
#         "4db3aaca682130edbd22daffaa2e0008",
#         "4e29e462314fb5e29f1b4c92b82dfa3e",
#         "4f9dc0d2aa7e21448033a4e8fdc12f98",
#         "4f9f800eda3b835ff396b1f906378ab3",
#         "502d51429b2a0ed8ef0ae2a2f328548c",
#         "51076bb3143519e9b31b4ee85f6ee18c",
#         "515ee7b8ca3cae9ecb3a820149f703eb",
#         "519fcb2e4815a9c526b2b8e5f52544db",
#         "540b9f69c0e1f30a9195268a085d5904",
#         "565f59cd38899814f6b9c95e77c90151",
#         "569c8d0b0603414d58f2d1dd272bdf06",
#         "56ebfc8e451e7086b3fa48ff31b595d3",
#         "56f21176587730bdcdac785573f66a53",
#         "57d395decdeff016ed92b57b31aa0486",
#         "581f7a2f0d7bf712a4490405b6fb3ed9",
#         "58add932a40873eba2a41da1cc778ed1",
#         "5997bb887bbdc8ded40e2494ec12a7b8",
#         "5a051e40f583b8714239faa9bd4e1e8c",
#         "5a3f94671fa46d361fb9d89db5109c88",
#         "5a77cea3deffac9bc7a0526a0ccf3a4d",
#         "5a97dc9c0a8864228c5aa9b3451fad42",
#         "5d5d1abc91963992eee5d3b51811cc33",
#         "5e084395d9cc8522a06efb9dd7d7611b",
#         "5e1a300e8ae73644465f18fd2ff1a8d9",
#         "5ef15d83c3a25d66f80bb8f5a53bc557",
#         "5f059208f0dce946e685f89281fa27a9",
#         "5f069dcc4a34c7441c0326559348046f",
#         "5f6706ba94ad521fcad4da2524c87ef7",
#         "5fbd7057177bde05a065c99665cc2dc0",
#         "5ffc6eeab95755bc24e6e38bc8c49fe7",
#         "606ad847bdf853657367e287fd162f4c",
#         "60de2f44a9922906bcae7b968d184822",
#         "60e51071c8525bac2274275bb40d6e08",
#         "6177db69d9f816af3edaf79d1bf79b86",
#         "6187ff51a3c331a0657711e1908dca81",
#         "61b6521c239f6bc32fec6a66758fc6d3",
#         "6244ba90ac405bf468555c90224388f9",
#         "62c1d59fc3bc28fd1c9e918f0ebb5466",
#         "62d66a7f25ae31249c4daa7088014265",
#         "642fea2d50db6e27ff5e6039f98cf444",
#         "647925b1d1a87331b8bc733f0ddc2991",
#         "6486160c9d58a0b9b7f78c9736ec866e",
#         "6594d67bd95a2e22166a6b43bffb635c",
#         "65a48fb2a18a2fb6b0b47772c3b88be8",
#         "65f39fb322a7365ec56046e38d6dbd8f",
#         "66187469fef2716b531cf2bb4db605c5",
#         "668c009a6fe69c7416b3eea2d985db2c",
#         "670e008f54da7ef6b716a318cb5cc552",
#         "6754d1fed088a1d50338879971ee553a",
#         "677fee7246e70eb1d80c3d6a82808b26",
#         "67d502555febc4e9be3797fda2bacc66",
#         "680e24f1572ce1938277c588e6e17bb5",
#         "68b1a9e5cffbaaec861ddecec34134a9",
#         "6a589079f75eaa2c29cc5950cde3a60b",
#         "6aed400c6972d41d7ece992eb76aae5c",
#         "6b100c7c78e2fb4f251cf47a1c7d2130",
#         "6c1f15d7883157cfea4e56e365f38f55",
#         "6db045e19d019bb3234e2bd53fdf09b0",
#         "6e6319108e432c0d155256e07b6df519",
#         "6e9c02b31e73f04ec61e8e5ad5f89fd5",
#         "6ef857249b387283d55575bbbddecf04",
#         "6f50b773108026043e3c907266823a59",
#         "6f5108b3759df73649a28a75a06003af",
#         "6f73bcddf021ceb3c8edc0795981fd76",
#         "6fc5a255c470a2652b9adb0c30aa1fec",
#         "6fe9933ee2f5e8b8f77dac808d856ab8",
#         "700b664eda64175a5bcb7b97de35db7d",
#         "709496a10d16d4a2ad1b1ac55e9b7648",
#         "71a39ea318026f4bf635caa7add05338",
#         "72ad6ded2f6f976ee562b1538d12e912",
#         "72bf2c2de23c10782e75c3c87662ea4b",
#         "739aeb7e279d9daaa511fad86c7de27d",
#         "73a592b8dff7baa5a017138a6742ff13",
#         "742007bcb804d3f9e07de13f68ec42a4",
#         "743f11306848c5b190219a0df2efdfd7",
#         "74c3ead702f9ce45efc7fa256ea51fb4",
#         "7546f4bb203fe9252794268b19b48def",
#         "7612be713c627acf8db4e7a7be6f9d16",
#         "765a63d85ba057c1dbd4f9a8d2b4561e",
#         "76bee5b64aa4b2f04ae6b984c06dd3ad",
#         "776052a3cc0d86bac816a76bbfe40348",
#         "77a2de78312ab33753b9e41e2df49ea0",
#         "77ab42cb7a833816dce91923ed0d6a98",
#         "78584e50467e74da90e22324f787a92b",
#         "785c0ee0a260f35c0323cc196492581a",
#         "7ae35c2a69a74f391fcf90b5658ffa1f",
#         "7c7e4dfebdb245257eb184d6de69f1d6",
#         "7cdc79d066be06fb04111bf299fe3a5f",
#         "7e9c609ee60b7b18148d802fdf695adf",
#         "7f2685a536f57fefd4655470eb6a7bb1",
#         "7fbcbbb6443fda439e44ec87b7fe9884",
#         "815450b8877790fcaab0982e45b3cab5",
#         "81d980ca798a7d1df286a3f38ad153ad",
#         "82188d18ae315ed056dbbcc553fa14cd",
#         "8241651808c1e09c8a4c74683bc71f10",
#         "82507d915f6e9e390bc8b34f57a01e50",
#         "827595c7f4cb28a5743761ae5dcc30ae",
#         "82eb64b90c57be86d17bcd555c755e26",
#         "8429874776bb0cd6abf3c702658fad64",
#         "84cd2451c5ef45c3caa02a2ab9a2f01a",
#         "85186225b70e62c97d3c71561665dc48",
#         "852835dfd7bd234892ae88044ffc4706",
#         "85d0a370075dfe7b700617015fa9c8bc",
#         "85f4af2a560ac7b7f108c2e3b98efd80",
#         "8685d112dab556f3e26e0216ef1a27ae",
#         "891068b603cfc5467537f3281eafcd19",
#         "8910cb061488ae2c14d2ec6b6f62c992",
#         "892fccfc414fb5959171e0b05e85a41c",
#         "89754b86297b68064bf0a99a28dd2361",
#         "8a1594a29c73d65e2047cb4a746bbfc5",
#         "8a15c43cef15fc564e73dcc68eb190fa",
#         "8a6423a3a1c7d012c769c05fec989bdf",
#         "8a8e798ffc469a29017ea5a0192558b7",
#         "8bc0d58d2c2e0f590307de3630735483",
#         "8da7c5b7934cea8d07472f33757d7342",
#         "8dbbbfd075cb6a562fc30dfc3e132150",
#         "8df2787264efe555f09022f826d8d62b",
#         "8e6abc81faf879f60ff0760d52df472e",
#         "8eec34920f4bdd4b7eefbd703aa98c4f",
#         "8f1afe4619d4b6b53425b4e0c96415a0",
#         "8f715726c8fbc6a66e7e036a038557b2",
#         "8fe79d89c34f785265c0537de3b22ac7",
#         "922eebba79302d8a2fa585f2c413225c",
#         "92325f935cb5784d5000fa1a989dabe6",
#         "923df72c472401d3ef65028d714285ac",
#         "92e6f4f2fb3d7b1c356a4cd5efa437b5",
#         "931e333721f747c1fccd4a9bb660570c",
#         "9369c1ae64552580d48d4a95bb02b629",
#         "93ae6ab0a6987640c6a9a7281beccb20",
#         "93e2fa7406b99e14c0cb96bec1763e30",
#         "95c32ca1501cc7a05eee3c1c69a4b91b",
#         "9626cc19df860a9c6b1406c460e53a03",
#         "969b18ba86c93283e2cea2ba30e0b2e0",
#         "96d2f3c02781ec920227ec75e502f472",
#         "97db845ae73353ab7b6700d154b265ac",
#         "985e0b124f3f2457367934e1c550171a",
#         "98bac72de931367722b530be5d6300eb",
#         "9a3a50d57e4928e4b56266a184e980fa",
#         "9a40379f538ca3ce6b4fd523f9416b43",
#         "9a4459c616dbacacd2deb9fd32b311f2",
#         "9a542c6603eef076406b9c8044f08511",
#         "9a5673895a764e92adf3c3b5cc122cc1",
#         "9a7fdff2d189a51d9c0d8710ee56f263",
#         "9ade40db4896667e385b8f34c927dc01",
#         "9ae2688b74c74df86e27925160e5632b",
#         "9b9e3a566c5721889910ce299b2ef5a0",
#         "9d14bd74e792969318af0fc4d14f0966",
#         "9ec52538d50f60365216378a9daf0026",
#         "a039af206a6b96e04e7383d031b34cfc",
#         "a13f1e963d346a5fad8a9b82ca1381b7",
#         "a2309c7359fb941a1958c36d6a1896dd",
#         "a3b0124a89cf0cab4da467f942b5e59e",
#         "a3d84de63e4240c78725174879345688",
#         "a4ae76df7364a1716a30b3b7ed56571f",
#         "a4dbfa24f1f347e126b4a9c8cc4892b7",
#         "a5715eea4ec68a803a98eaaa7084463a",
#         "a608193992ac1ba59ac5a4a0ba7c283b",
#         "a60caebebf71ab5f661d65945854d213",
#         "a66746fa37e21c3d1f08b430bcf12b91",
#         "a66d675d70b4c1714eaae1e552ed772d",
#         "a6c3679403a9051eefb7995ba78cbb63",
#         "a718f9b5510900383c1fc3e8b0c0811e",
#         "a76b10c6be40396f7df2078bfb2692f1",
#         "a792cf17a828795b2c64083c829d73e5",
#         "a7b01cff2e0b82fe0f3ea032d39e91e8",
#         "a94cd3ad9354c86966d556f56634f9e2",
#         "aa4a7c18114672dec653cdf26e570d10",
#         "aabc7bd7fab2ffb75f05319bb3707110",
#         "aba305b1298e1b1f8f26eda135df8f1b",
#         "abca25ffc30b324cf7879284cf232dec",
#         "adb65f2016ef70d8d21239770be40575",
#         "ae186d8e31b715c9861944a4ddc9fde2",
#         "b01c1e343a95c05c3e0b2de84636140b",
#         "b04a0d21055c36349c93eafd9acb10bb",
#         "b09454cfd21b475c1a3b052e0b133836",
#         "b0a8fba30b8b9757e7d588d46a9eb950",
#         "b11735b7beec04c3371267cd445f477d",
#         "b1b80dedaba45dbbd79bd712381e81ca",
#         "b42055890bcac293bad53514ab9e00a4",
#         "b42091b808357414e967bd63d2ff38e3",
#         "b61b9fe640bde563b706df58c085bb46",
#         "b6ba3cd66f3318b89dc3e0844859196b",
#         "b6dac8bb071e190b219a66eed20bdc43",
#         "b77f5dd4ddbfc06cf649a5b70ae11d68",
#         "b81a2a6802d9895ccf2a5b0125e819b2",
#         "b96e16176132d8e435637efa9e47f83b",
#         "b9cdb34d8c12e41a4ff33ac7823b2504",
#         "ba0a14cc5ba8fd804b26517065d58fe3",
#         "ba2e12041e732d7a3e08489e60627b7e",
#         "bb0f24f6f38a4e0c778baf00f06b2e5f",
#         "bbac241b779acc9946af01371aee7ac3",
#         "bd7d378e6cec5e3c88f8c8d6772d2926",
#         "bf1923d10b5a72fa792fcac49cf10068",
#         "bf59e1cd834949b8d4aaec7a9ad87bdf",
#         "c2278232f176456ad1982639c55a081b",
#         "c34d2f552319100de448a65b375f3d10",
#         "c462825a750d524aac648c43baa92c1e",
#         "c47ee777c4270122799ef2dc46c8890c",
#         "c4fb43ae646f17d1d2efdbad529ef30a",
#         "c55593cf74f3cc1990569c2ef939c1ad",
#         "c582cefd7cec0019d07126cfca3b88c1",
#         "c5d0b4bffcb765bc2cd176c6c01dd4ff",
#         "c69d26c8b32968a3ec6a1391d2fee5ba",
#         "c89ba14c5e010e9162004044604d50a2",
#         "caf08ac73b45ec8394fd83cf76fdb390",
#         "cb0cf4b32e225e1c6a1b6b09622485d3",
#         "cb7ed93ba26855fbfa8b3878387a9275",
#         "cbac626f1a8975a2845aa2202517eb5b",
#         "ccf28657b064fff9cd5d3e7ad4e03287",
#         "cd35fd3044c8e005be6022629aa2d2c6",
#         "ce42056688a6af61faab3df9e4b28e49",
#         "cec46ab9161a4d3954e990df5a526605",
#         "cef220f18afc3ccda50c39a3e606ad13",
#         "cfca9917139c51fcd5ab1ac577b6123a",
#         "cfd0e69e5b251123f3769408dcd75dbc",
#         "d0ce039cc1ecaec5a2bf37489b66c55d",
#         "d1d1e2b1e3a7f6fe80dca294d6e78821",
#         "d1d54da19545808159c5f10356f938f5",
#         "d35c87cf2912749cda374c3f8cfc9bf8",
#         "d4b3a3d9685e50666fda0e43b26f4f5e",
#         "d5d07910a01fbe3eb02a85460c1bc24e",
#         "d5d462bd44acc024e7f94c45a126ed72",
#         "d5f8dce50e55744d4bedd1fd154eb203",
#         "d6733e5105c3b70941c78e39c610566c",
#         "d70c4d29f1d88d0e45ed00f25b8b5236",
#         "d7da3e4361138d3b8f1a0bb848143fb8",
#         "d8c4daf693dc7cd2123f1ed4bb297e5c",
#         "d8e943d0042885cdf80d0d736b2183ad",
#         "da1bb160853d7563da9b04d26b30f23b",
#         "da76b65f6e4d53a10e7a6008bbf14deb",
#         "dab593c09feb29957f55460cf7bfd2b8",
#         "dbc826f84bb1572a3c21e02930184ffd",
#         "dc05d39e1ad0cb56fa1d367b0fd4246a",
#         "dc2f737c4b9426c90b91d06b52410a10",
#         "dc9b63c2c5b89935569d2b27f1f1b364",
#         "dcb86efe4c0026fcae7d2a2ad9128099",
#         "dce74a2259f95ad37099c1fa82997a6e",
#         "de1cdb7570ac4bc33fa402d998db7ee1",
#         "df3f6ec6311e36ad3ced5188b220e4fb",
#         "df4a50291bff0dc1d0b5df709935e18b",
#         "e01203e5d54d0fd311a9da510f47029e",
#         "e17e89dcc270c22fe808fe11271b67f6",
#         "e17f578a409499812557e19f94e430d2",
#         "e189bfc79f1094e5835eadb7b1c31975",
#         "e1aed1d3b6fcf4613696b1aa41957f70",
#         "e67c7e33964ff47f46a754eddb4698da",
#         "e7914204932a960896884b67996709dc",
#         "e7befdfc5e8bee8b060227e265c56756",
#         "e7cba746e3bac78cf98eff0cc67623bd",
#         "e943102cfb0a151f6af14fba9b0f5334",
#         "e94ecaab1a59165a6467f7667d0c3ef9",
#         "ea574abbe135635dffac00d9a9ff98c8",
#         "eb26fa83aa8273018ff0b4c5ccc2b528",
#         "ebdfef46fcaa207df4d9eba5efa56828",
#         "ebe4620f24cabe5b6dd89f6c29db6708",
#         "ec2c095be512c36bcee60c63e21961c0",
#         "ed26995d905d3ead593da9a6664a212d",
#         "eda5021662ee8c860e4b96b5011c7c57",
#         "edf4fa2d3c807397606a2e0fbdcb9a1b",
#         "eea8eb964bc9efe8f46aeb434081fd92",
#         "eef157b6376b45e200861ae233c9fff0",
#         "ef019e6696c4d44ace6b3e8fab77b598",
#         "ef494f1234c40e3624777bed52212c10",
#         "f2ef7c58e26658735f5911ad3f26396c",
#         "f31d41aee903f6d158a031e96f17e847",
#         "f32030c518a4437a88d787aaf4bd932a",
#         "f36d7a1a24fcf35ec2c78009088b26c2",
#         "f43d4c539c948f301c72f292e6007919",
#         "f5cf1833f873c6359e0f99d7713d2f47",
#         "f62f09340d4b89d04e29ed91ce1bc59a",
#         "f66d87a85d818c009d4a4d2afd5a4c83",
#         "f6893fbb9a257baad8feca157c0bb0a6",
#         "f790ed55ebf494a51cbb6176aca1f228",
#         "f7e0915d6afc2994f3880466b2e79c1d",
#         "f8429ac6744095d237afbdd5ece60c2b",
#         "f84cdca4787fbf23483de7fb089d9729",
#         "f9fba4a579593e642e32fec916c3708a",
#         "faa032714ad3730882937937e64acb59",
#         "faeafef96958ed1856a9256ce5a1db2f",
#         "fb22332c3a2f4d8442acbc7c3d23129a",
#         "fb65468c9267dda144fadc5edb527886",
#         "fc1a7aad9c65a6849faf7d967553f3d7",
#         "fd2a0375e0f124884f027a6deeae39e0",
#         "fe88137635b556798b47aaa5deb1538b",
#         "ff5d4b2a8fb8cb718560604720884682",
#     ]
#     for hash in subtree_cache_hashes
#         @testset "Comparing $hash" begin
#             @test compare_subtree_cache_files(
#                 hash, length(response_json["dates"]), "2023-01-02"
#             )
#         end
#     end

#     # Clean up
#     rm("./App/Cache"; force=true, recursive=true)
#     # for file in readdir("./App/SubtreeCache/")
#     #     rm(joinpath("./App/SubtreeCache/", file); force = true, recursive = true)
#     # end
#     rm("./App/IndicatorData"; force=true, recursive=true)
# end
