{
  b3sum,
  fetchurl,
  lib,
  nickel,
  python3,
  runCommand,
  rustPlatform,
}:
let
  modelRevision = "d81965cb4e1a9f96696b4f70b84212b8f2e43216";
  model = fetchurl {
    name = "rwkv7-goose-world2.8-0.1b-${modelRevision}.safetensors";
    url = "https://huggingface.co/RWKV/RWKV7-Goose-World2.8-0.1B-HF/resolve/${modelRevision}/model.safetensors";
    hash = "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=";
  };
  modelBlake3 = "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5";
  tokenizerArtifact =
    name: hash:
    fetchurl {
      inherit name hash;
      url = "https://huggingface.co/RWKV/RWKV7-Goose-World2.8-0.1B-HF/resolve/${modelRevision}/${name}";
    };
  tokenizerVocabulary = tokenizerArtifact "rwkv_vocab_v20230424.txt" "sha256-5t7j1OMbTVxArJlQisbHAc7vS+1oG/IWfOmpCFUryok=";
  tokenizerConfig = tokenizerArtifact "tokenizer_config.json" "sha256-TgOqD11rGkAGoNnp8HDwFBjnNKsXx8SPKDM1lta9Xik=";
  addedTokens = tokenizerArtifact "added_tokens.json" "sha256-o0nK5s2qaAz2/A0pKbFvKp7bQ+twJ7LjRLHKgGOFT7k=";
  tokenizerImplementation = tokenizerArtifact "hf_rwkv_tokenizer.py" "sha256-qspeag9W0EPKFlTp3K+Qb888DgO1FyhjrXUGDoaFoQ4=";
  specialTokensMap = tokenizerArtifact "special_tokens_map.json" "sha256-H1EppN7ADOM+XFzScmyVKyKkeCcyHu08UY1DXUpkYBU=";
  modelConfig = tokenizerArtifact "config.json" "sha256-VcFZ/IlA4WVXpCsE8K7QN0TxdiIcwSY3aUqx9+EMTG8=";
  generationConfig = tokenizerArtifact "generation_config.json" "sha256-2milZURvylpqKvSzCIkS6VOWX7+m6WgBmhTXVj1Y2Tc=";
  hfModelingSource = fetchurl {
    name = "modeling_rwkv7-${modelRevision}.py";
    url = "https://huggingface.co/RWKV/RWKV7-Goose-World2.8-0.1B-HF/resolve/${modelRevision}/modeling_rwkv7.py";
    hash = "sha256-CwBZk2Oziq7f+c1xUZ1aDqfHSOHXcaTXQkNp+S6FChc=";
  };
  flaRevision = "17dd5662554d46b6bcb1d1ff728cebb461c9aef9";
  flaRwkv7Source = fetchurl {
    name = "fla-rwkv7-${flaRevision}.py";
    url = "https://raw.githubusercontent.com/fla-org/flash-linear-attention/${flaRevision}/fla/layers/rwkv7.py";
    hash = "sha256-h6+adGlQ+98G4s/NnRDZwM1arEm1JUurWhrGhC9J/YM=";
  };
  officialRwkvRevision = "e6f74b63a06e08606d130043599d218209628bad";
  officialRwkvSource = fetchurl {
    name = "rwkv-v7-demo-${officialRwkvRevision}.py";
    url = "https://raw.githubusercontent.com/BlinkDL/RWKV-LM/${officialRwkvRevision}/RWKV-v7/rwkv_v7_demo.py";
    hash = "sha256-PYNJReeIL19qtCM5WLE20KSbwmMx7ASOtkXUjKhxbN4=";
  };
  pythonEnvironment = python3.withPackages (packages: [
    packages.blake3
    packages.safetensors
    packages.torch
  ]);
  expectedSecondTokenFingerprints = [
    "6e5391b0a6ddd727c0a5359b18676bd5d3dfd3fcc69f088da9fb15bba69934e3"
    "34cbe8c4586627577d9a51d49db1b6a2106b50f616ae5983593b0c4196488b33"
    "5a8b7ce512d92fb71038218c03441012ad096e990749aa7020c94ae9ed9cd176"
    "5aeeebb2d8d1d7f83b82df3fc1a810c4191ff297cae604d010001640ded69650"
    "7f43c153e6a3b25b1dc0d8aef8707aafb7a8983d49e22f42917ae0663c10cd51"
    "1aebc84d2384d3d3550aa9f4a123912ecad1ae43c6f127bcdc1207fbafb2b88e"
  ];
  expectedFinalStateFingerprint = "63718d8139e7a70770d8ca7b0663faca0d87ea3d5b99a45a5d895a827cec868f";
  expectedFinalOutputFingerprint = "cca5dded173404e19115bc749f25aab0c26200282a739bb3da98923d2d9a8e26";
  expectedModelLayerCount = 12;
  expectedGeneratedTokenId = 2;
  expectedGeneratedLogit = "2.8641083";
  expectedRunnerUpTokenId = 33;
  expectedRunnerUpLogit = "0.89640886";
  expectedGreedyMargin = "1.9676995";
  expectedTokenFinalHiddenFingerprint = "af8775318ae4b28af27709dbe1052a8ffcd5bc58f3ae209dea0913801b334f70";
  expectedTokenLogitsFingerprint = "31e5a4c2f979966c1a8ac72b3af8daa16db0f61d33297f7aadea4196816b9662";
  expectedTokenStatesFingerprint = "7edee48128b2bb3f9f874e9cbc491d44a2af7f5bb19c53a595ff0bc8eed108fe";
  expectedDecodeStepCount = 3;
  expectedDecodeTokenId = 1;
  expectedDecodeLogits = [
    "0.04493069"
    "6.9543834"
    "6.486726"
  ];
  expectedDecodeFingerprints = [
    "04f6971c67f2fb45e3e8d26164a872b6e7d4d8ba847f26ec170fcd347df6e89f"
    "762581cfa10ae11cde207349bd844e59fdaceca5c9288db937928c4f356c3263"
    "e61647dfa4e341599f939181919100509c652797050b76b4f2f80ada7134a591"
    "812728ef2bd878f91df9d2ede34aebdffa19fc83c25319d8cf24d1b041bfa30a"
    "3daaa9712bb4851e5fcccdc6d2b7644c9c29b495c7ece0f483e97cddf782be9d"
    "15658cb672bb56cec6132e4b72463a5966db26fdc471ca631b3a308112bf76a2"
    "401b9ad0f87cfc436fc53fe3d1e977c6aaba1546582e9f07daf46549730ed7ab"
    "ccb66a0dde8fc0490872092dce9aa3b778a3b1d5ce0bb1d256d130ec7a423917"
    "56ab5c6de04f5e359a7d26390ce36b0c7551ef41dbcb998373ab4c2f0f344ecb"
  ];
  expectedMinimumStateCarryDivergence = "32.84725";
  expectedTokenizerBlake3 = [
    "3997a74891dd68ced8daadae0d7475274b08988c9263ca042896c8106967aef2"
    "b2411eb362aefa260493811c9414e8da589a19d6cec44e8456953507e293755e"
    "02893c22a1e92502fdd31ba4d57b6e574692023505be7ba82d68d1e3142ff02f"
    "0a2a88e97b455858e03bbbc83bb0228d8f36c2731fcb91cd94f05e2930e2aa24"
    "751ae3ea4b59073218a85facbee1536739b0aa26d5d5670e11ef6815e5bac870"
    "113edfd55813d327ae7e37987ee9c5ed123c69fa809670b3a0bcc07fd1e9295d"
    "2288838a56ea704a85691828bbc7f0ab2934c949b13a4d8f3af1b13d955ac2fa"
  ];
  expectedTextPromptIdsBlake3 = "f5a4ecffc7fe3f4205d095934a95d00ed5a633a02d8f6153fa9cc240c4488778";
  expectedTextGeneratedIdsBlake3 = "e714e3dc953afc6b24fb83aa0e972af26ec6a3145414a371894c4f1fb505fe0c";
  expectedTextGeneratedTokenIds = [
    3880
    45
    308
  ];
  expectedTextGeneratedLogits = [
    "7.5499983"
    "9.128329"
    "6.486315"
  ];
  expectedTextFingerprints = [
    "222a0718f72e1324673a043a6d9d9b3c5a7281457f481e7eae2c48e992165787"
    "842a6494a5eb01be12800aaf157054b7f87bce6753f96e83bbe8afcc5271344a"
    "4448243fad8b4b6e99cda3d36051c1c51a3c04e3b15981e7e91f9dfa638aea63"
    "b2b4f4efbf5e5ca66006760a5bceba3709c9063fdb817ccba6a989868ce1f9bb"
    "7b38e06b121655b31f405426c530a86983ac0fe406a5f92ae37489da1140372f"
    "a5de08fbd73c84cedc1032bb29f64f31c2c984d886c4928acdfc318253c0faec"
  ];
  expectedTextStateCarryDivergence = "21.653366";
  promptMaxMessageBytes = 256;
  promptMaxTokenCount = 32;
  promptMaxNewTokenCount = 4;
  promptFixtureNewTokenCount = 3;
  promptExcessTokenCount = promptMaxTokenCount + 1;
  expectedPromptUserMessageBlake3 = "fbc2b0516ee8744d293b980779178a3508850fdcfe965985782c39601b65794f";
  expectedPromptRenderedBlake3 = "4ad5b9a4f9b23f30294d312c06cd4990196c9f064fd46c0c562a883de52426dc";
  expectedPromptIdsBlake3 = "9faebfda36655992fada28a962424b5a232b10464c1186a3df075dbcafff8587";
  expectedPromptGeneratedIdsBlake3 = "1b1e2ebd4fad81dce97e84c1a518e562f115bd5a698743b170df25655410d6cc";
  expectedPromptGeneratedTokenIds = [
    36786
    34
    308
  ];
  expectedPromptGeneratedLogits = [
    "6.8237233"
    "8.615999"
    "6.9682403"
  ];
  expectedPromptFingerprints = [
    "f73020d4121b16d3ed6c5e3c0d3ed2ae9f37edb2e19c7150b3c98c3c9b86923c"
    "323bc686dcc6c3d4d5e8cd508686dcb88688ac94d19933f1ab202d0ba85c332b"
    "197d52fdc793bf7122acfec1ed1fb19086be91a8069f655eee4ef4f811e3d4ef"
    "80d100d77e820351dc17a62bdba795fe82ec7cd6606f6768053ef085a2bf2ceb"
    "e8cbffe2d965a92037f3a76a43624dea614b4435d10f0c341e4ad956736424ea"
    "cc77a2cab3678c33cf311c7854d1632d054eb4e38ba3ad04fe2e49692aa097ad"
  ];
  expectedPromptStateCarryDivergence = "22.658165";
  expectedTtwkv7BoundaryCombinedBlake3 = "44d91ad223079fa9ae5f6f0dc9943fc6d13cc25cb09262111ad433c7e6288494";
  expectedTtwkv7BoundaryArtifactBlake3 = [
    "2f2bec8195c8fca1027cdb8ef9421921643cc97db9404efe84b5139432096f89"
    "e549e829df1f6a05c9e8cbbc0b1e08d078196de57731f54a16cfcc4c9849a0ee"
    "4b0248fce75e5ff0d462be2edee6c16c1f2e2f68f1b9f5dbf696e9b3d1f7699b"
    "813277dddaee3ee19e87ede402bd65fa0393073c9fb86fb12096d1531676c68f"
    "63a08981b8cf0c852cc273e1626ab8aa77d19b141746f729af7cf269de41893d"
    "ad9f5a87a3dcfd04aebef24e0faebdfae30ec06d27369d2ff77fef90c9d38f66"
    "be643f1302ec76ea76ada70b24a830a3398bc463a39915226c61fcf8f67b52cd"
    "9af55cd740a0534c91e6656da5e0fca63386e06ded01d183157d07cba6ea50e8"
    "c76c943bab4cda028b5edae8393919ae3f93f35b79b6a02648d4617e21b414d6"
  ];
  expectedTtwkv7BoundarySourceBlake3 = [
    "3dc1ff13a5ebff20cb32cc43727ec6cbbd1bd6ba828c3f6b60a1acbd193ed30f"
    "5b882f55afc0afb4aa98b243708ce506b895c60b9aee83aea225a4b2e11b30e5"
    expectedFinalStateFingerprint
  ];
  expectedTtwkv7BoundaryInputQuantizationDeviation = "0.00641346";
  expectedTtwkv7BoundaryPreStateQuantizationDeviation = "0.0017508864";
  expectedTtwkv7BoundaryOutputSourceDeviation = "0.00065533817";
  expectedTtwkv7BoundaryPostStateSourceDeviation = "0.0021299124";
  expectedTtwkv7BoundaryOracleOutputDeviation = "3.7252903e-9";
  expectedTtwkv7BoundaryOracleStateDeviation = "2.9802322e-8";
  expectedTtwkv7BoundaryRetainedStateMaximum = "1.2421875";
  observedEvidenceRoot = ./fixtures/ttwkv7-device-2;
  expectedObservedReplayBlake3 = "0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18";
  expectedObservedTypedEvidenceBlake3 = "3d7c9c9f256612f5885fad7cd7aef9b73dfcea11df83da8fbe28cf7a625dab54";
  expectedObservedEvidenceBundleBlake3 = "2c184f63f7ba298aea7f3eabd189494b4b1d65e9e21c8cc7745c38451d62aa31";
  expectedObservedAttentionBlake3 = "3ceb34498ce82d176e17a2372a3213e7008f13b429239f8ff3d718bafe464d37";
  expectedObservedFinalLayerBlake3 = "f9b56d68f21cea629b101ebe6d2c56e709ace8beb03f37b51cfc20beead95581";
  expectedBf16BoundaryAttentionBlake3 = "b577a38ed9cad20ddece194f1618fd27b27a81f72cd780a87ddbf4e51d9ac39f";
  expectedBf16BoundaryFinalLayerBlake3 = "67a8e5d826efafcb9fbdcfbdcc3135d80352ba5d34e8cbd826b0ae9efd6f0b20";
  expectedSourceAttentionBlake3 = "f6f21abaf40152a89d54287b32b5e1da316c2b21432def1cf918006ba3b87763";
  expectedObservedFinalVsExpectedDeviation = "0.0017949939";
  expectedObservedFinalVsSourceDeviation = "0.00022334047";
  expectedStateCarryReplayBlake3 = "58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33";
  expectedStateCarrySourcePostStateBlake3 = "04adbbbeddffa682c5be3d10b450791542977e498672778d097cf43451736cce";
  expectedStateCarrySourceFinalBlake3 = "1044e5f1eec226adb0e4b3e623e7a92861328776350c7f8eba4555a23502df13";
  expectedStateCarryBf16PostStateBlake3 = "8e61bb8af9d99296632933c93152af67bce8cf9a7846781f8025d656b0580cec";
  expectedStateCarryBf16FinalBlake3 = "68fb5eea444a7f27ca9bcdfa4ea99fffb7f609ed6f14dcf9b2aa6f0cefb59c1f";
  expectedStateCarryObservedPreStateBlake3 = "f8c894bac89637de0885f6fb351b7b21dbfcaa7a6f665d22fd0d27838de0257c";
  expectedStateCarryObservedRawBlake3 = "cc9b373258d7a49b44e1ab3d2f2d06853b549f8b72acc0f007a4d591005921e5";
  expectedStateCarryObservedPostStateBlake3 = "e6069234ca935f70dcc8278876fb15cbacc0e374b52e6f33efa5482b5daba7bc";
  expectedStateCarryObservedFinalBlake3 = "67a0a53d12921095d47995f4a4845543c8e00e569e6f94c1b43fc5a451a2b39d";
  expectedStateCarryResetPostStateBlake3 = "69e597e791c859bb35808620efd6a166047b8b1e0e0844e8dd06c4dcecd85797";
  expectedStateCarryResetFinalBlake3 = "1f32242632bab3ff85bc73c0eb4c4ec431c706096e8383e6d3d0ddaea401fb5e";
  expectedStateCarryTransposedPreStateBlake3 = "ca779160e627b05b2013b19e61bab1d75c2ac3647cd92711331113d71a5ef805";
  expectedStateCarryTransposedPostStateBlake3 = "2d1b67ccc063338d4b5df3b829cd5da8bd2ff4487b7a04858e1ec0d54fc3bc8f";
  expectedStateCarryTransposedFinalBlake3 = "ad2d12f70ce5f1e096c3e4db857ab1aa7712e008d84a43521f7942ec9cc96af3";
  expectedStateCarryObservedVsExpectedRawDeviation = "0.00024414062";
  expectedStateCarryObservedVsExpectedStateDeviation = "0.0078125";
  expectedStateCarryObservedVsExpectedFinalDeviation = "0.00032252073";
  expectedStateCarryResetStateDivergence = "1.1815033";
  expectedStateCarryResetOutputDivergence = "1.3526523";
  expectedStateCarryTransposedStateDivergence = "1.2164612";
  expectedStateCarryTransposedOutputDivergence = "1.3400576";
  expectedModelCarryReplayBlake3 = "74306bd245d0bf3b4de9ce5c5f0736edcb516ac9556bc67e7c8116653de973ed";
  expectedModelCarryReceiptByteCount = 41591;
  expectedModelCarrySourceBlake3 = [
    "b71dc8f926863ce6cdec9397686590d11ee1de7709fff5d49971792eb0447bc6"
    "602dfc220819e2023f84d0094982e1a7338ee699be44f95a17159d834d8fe50f"
    "a4d17e9d52cf2b39036da43dfa70988883df865bd9a263950f88ebb772cce097"
    "1031e9be4eac463b3a7244fa851eeaa56bda27c09c2973d920e36709d80b4c19"
  ];
  expectedModelCarryBf16Blake3 = [
    "37b2925cb4535fec695b51fb07aa0b390b1d7b3c20dc34e4cd7501c849b38ef0"
    "c4c5578b5748205962f61c64c4c403cb810bbc617ec9b63d37546df50db43e7d"
    "240cb16de60cdcd2a94e80a0f6b8725451d46ef8921afc131cade192f0fb7901"
    "0923301470d60bf84edf6d3136605586726607f7212ddce4d82187c208a09e1a"
  ];
  expectedModelCarryObservedBlake3 = [
    "61382a251ce618622dcd695737b08fe8981f5e8d435b8261887237d97210dc64"
    "60de3a8afa23de56006671a09aca735e17da2946807e827b5dc731cb539859ec"
    "b1ba3cdf9579c2233d16e22168e0aa4da0447273c10ff7229ecfda0a34d8482e"
    "fa8b37ad9d490ea8152e1eb3abba522348e1c5181bb94f031a03fec907f4e9bb"
  ];
  expectedModelCarryResetBlake3 = [
    "545513fb11d45f840df20bf03d85610a343824a2ecfa1a3bd385dae49ec20a88"
    "b7f02cd85283a203815f1d85eff3333cec69ce3df515d8fc3a5a43821c8c44fa"
    "c53deb06759eb769b069d617eee78c15e2bce6dc7da92aee3d18c398ee20b4e8"
    "1044330769d93e68a14e0abfed48b6657a83f4a8e2cafebd26f6e2fd52ee896a"
  ];
  expectedModelCarryTransposedBlake3 = [
    "c99573a422f61839f8ae97ab4af6a35dd4cb89490e28dd9cb6fd06a1011a38aa"
    "40d8f13194d04246430563aa0a6f315d731b626b4ca6aebbef529cc2a1ec72f4"
    "07e86dc660427fd3a5251e42890a25de738a3484d5ff1eaed79e98a3f99f4745"
    "e2b169a0b7453fc2e4b878f4aa32909e481d7cf4b77d4d7b330033c4bd091a42"
  ];
  expectedModelCarryObservedVsExpectedLogitsDeviation = "0.005589485";
  expectedModelCarryObservedVsExpectedStateDeviation = "0.01061058";
  expectedModelCarryResetLogitsDivergence = "0.742733";
  expectedModelCarryResetStateDivergence = "3.5060477";
  expectedModelCarryTransposedLogitsDivergence = "1.1483517";
  expectedModelCarryTransposedStateDivergence = "4.229019";
  expectedDispatchAbiReplayBlake3 = "65ab5583647dc79b1d1c78870cedccd6f556a58264dd9b9640c9214f010fe431";
  expectedDispatchAbiReceiptByteCount = 5234;
  expectedDispatchAbiSequenceBlake3 = "84e59e1fc4bb63ce7facc8ed34ee4d598335640ae157079fe879123fe03b6d59";
  expectedDispatchAbiTranscriptBlake3 = "ba8d3c401468f9ba751afb4baacc6c353242f2dd23f129a808f002b57d869ccf";
  expectedDispatchAbiRetainedStateBlake3 = "0820459ef5213b56abe294b26b63e4cf24c18c642089c8eebddea9352375a97a";
  expectedDispatchAbiResetStateBlake3 = "b6a12cc17d7b02da79cda6451cbf09567411e54abd9958fba89a0d41e0c269dc";
  expectedDispatchAbiTransposedStateBlake3 = "946815abb8242af5035b426afd7746fab14b5d4511cb4408045f40d188f089f7";
  expectedDispatchAbiResetDivergence = "0.0023040771";
  expectedDispatchAbiTransposedDivergence = "0.003791809";
  expectedModelDispatchReplayBlake3 = "81c3b5c9904d2469b89d3f6732609514996fbe910a0c9ff0c150fb6044832b5d";
  expectedModelDispatchReceiptByteCount = 43080;
  expectedModelDispatchSeedBlake3 = [
    "ad0016542abe85df264a65b9083b30fe61b844cd568a8696fe457d853c47a0fb"
    "9e938d7dfbfc02c0b16a064a28c7fcbb10dc4294d8b00fea7fd3aa8af22a5c95"
    "b0984844f004f2a92bd06efcdc5dddb692e69948b9bb0d4599c4d5c3c6ce4afb"
    "07639ace76eb47cd7ce733b0754d1905af3c117701821850da9abfc695d232dd"
  ];
  expectedModelDispatchTranscripts = [
    "c425dfc393850ff6a5041837d7904bb75c825be14e16d9df775d1b510cb04d38"
    "1285fddeabae7153596a3f5bc6f9cc6063d441046a6ab261123dc6c8085c2715"
    "ae85f1bb6595bbfde0b1c7e2d90ab3aa84e4b3e537d3d7baf5d286557aeb78ed"
  ];
  expectedModelDispatchSequenceIds = [
    "e8fcf5046591b9ca0147ece598b858b07744cc2a4ca24a6a8e8944d926d54cab"
    "e8a1ca1eec4cad16201e5214d1c30e31ba3dc3a0d8641e3eda7b99d0269384e2"
    "3cf1c3dc2f1ce354f4e21aae62affaf0637c0af09c1d84d369bc08becb894020"
  ];
  expectedModelDispatchPathBlake3 = [
    "904ca4c9005599ae4f61edc293c020b8fc5320eb1910862932a0e6a8408a69b3"
    "ef2c2b0c6cb617772e068dc8b886cf8e9c773b49cee4561881064ce5fb7981a3"
    "c520d204d96742b47c996e04ba7b244b2beb64a970cc25ded1aa549b99870735"
    "0c64c023c7655e1d88e87c3077b75862bd711fd1353bfa0b5299317dbeb4f15a"
    "0371b6e8be0ee060081c8fe02309ca450e26a3ae97e22bf10cb0cf0b50eda9dd"
    "732b71ced9fe143e40ea3ed1f40e82a6998fcc4cb8307534517b1a05712dd766"
    "281ca311f6dcf93145e2aabdd40e38194c95e9f81b27b9aa2c6194d1bb50a0e9"
    "82633e9fbdb31910b4502fd592006e2bf0bf3264b17319d27f15a304fa313a8e"
    "bc5b9849924b2a3c4a2d0ac4e569a6135327599cfbd19275400cc6982e477e23"
    "75740dd094d24b5da35018422782e98098a95595ecd233d5510647ba22b529ee"
    "5404025716b139d8aa45819e05076bd94affc89e80614763f74dc222b2dad075"
    "591e1eb82e7a4f4bae035954c5b1416751d1e74731b0edbe45d4475a6ec08a47"
    "f76d8978a0863239d7713f28c34168c2e2aadfbd08728685e33ce9529507b092"
    "d71476979c3c25314d0ceb8e8450fc2cefb93b67767d43e8cb7b903d27f4c657"
    "6b21cf3ad161b1bdeeda432c4e8fce09f3dba3538bc510bab3538a29284c52ef"
    "cc0ef40882c1341eff2ce0c7061df28ca4bc1b1eedb947b0150827a88b2f62f2"
  ];
  expectedModelDispatchOracleDeviations = [
    "0.001953125"
    "0.0009765625"
    "0.0001604557"
    "0.00035476685"
    "0.00018692017"
    "0.0009765625"
  ];
  expectedModelDispatchControlDivergences = [
    "134.51514"
    "15.3446"
    "55.0"
    "90.17365"
    "22.17935"
    "54.99176"
  ];
  expectedPersistentModelDispatchReplayBlake3 = "31f3e1dea79fb152ddb7ae5cc9049b97b8b38ca2a187964ee9edac5f5d45feae";
  expectedPersistentModelDispatchReceiptByteCount = 78154;
  expectedPersistentModelDispatchSequenceIds = [
    "44430cdb0e204cab653e913b781b40b0d1d9652f1f55b8ee49c0c937b014e35d"
    "903b16ad4f679f93c77a42eaa578129ea514de839a7e4a1767ab3fb3906a1d25"
    "77c9d1fa2737db58eee38cb73fcb6741dd00845bff08386338128359cdb5543e"
  ];
  expectedPersistentModelDispatchTranscripts = [
    "1be98ce2f01f8d56b92251fe6015439cd59acb895996bb702c5b0849b2844334"
    "d20f1192aeaef363f7fc331fd91484bfa404194a561ca6434c4d2468a4b9d1c7"
    "140f9dfc8c8b8004c1060d1cd1752c87fdb514151c0a428c0a8ede7e4fbfbf07"
  ];
  expectedPersistentModelDispatchFourthTokenBlake3 = [
    "e6069234ca935f70dcc8278876fb15cbacc0e374b52e6f33efa5482b5daba7bc"
    "095cb6d828bc9aae298b4268ed3522079c7b230bc1fc53219072530058164807"
    "c805e277fbe3106715b97c4c861f3b0ed2801d81b502260599c084f789072b5d"
    "018f3f6602aed5f823ae895ae3c1ecff8d71d1656f77924a2f437b262b6d867f"
    "9a1029744c3c1c9919e9661ad85d9800a35818ae19f3e53fdde3dfc1108ba89e"
    "cd88264434876dfd530ea85b6239663c971744813d98e7144cb7f1722a01aa16"
    "b94392b27c28769e830e80558753125e6f2f173aba2c67067e2ca6bb09427b3f"
  ];
  expectedPersistentModelDispatchOracleDeviations = [
    "0.001953125"
    "0.0009765625"
    "0.0001604557"
    "0.00035476685"
    "0.00018692017"
    "0.00048828125"
    "0.000002861023"
    "0.000011444092"
    "0.0000104904175"
  ];
  expectedPersistentModelDispatchControlDivergences = [
    "118.36631"
    "14.686736"
    "55.000004"
    "21.618242"
    "24.41396"
    "54.99176"
  ];
  observedOutputByteCount = 1536;
  observedPostStateByteCount = 98304;
  writerRawByteCount = 147456;
  truncatedOutputByteCount = observedOutputByteCount - 1;
  frameworkParityCheck =
    runCommand "rwkv-layer-harness-torch-equation-parity"
      {
        nativeBuildInputs = [ pythonEnvironment ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"

        ${package}/bin/rwkv-framework-fixture > rust-fixture-first.json
        ${package}/bin/rwkv-framework-fixture > rust-fixture-second.json
        cmp rust-fixture-first.json rust-fixture-second.json
        python ${./reference/rwkv7_torch_equation_reference.py} --self-test > "$out/self-test.json"
        grep -Fq '"changed_vector_rejected":true' "$out/self-test.json"
        grep -Fq '"malformed_vector_rejected":true' "$out/self-test.json"

        printf '{}\n' > malformed-fixture.json
        if python ${./reference/rwkv7_torch_equation_reference.py} \
          --model ${model} \
          --rust-fixture malformed-fixture.json \
          --hf-source ${hfModelingSource} \
          --fla-source ${flaRwkv7Source} \
          --official-source ${officialRwkvSource} \
          > malformed-output.json 2> malformed-error.log; then
          echo "PyTorch reference accepted a malformed Rust fixture" >&2
          exit 1
        fi
        grep -F 'Rust fixture is missing fields' malformed-error.log

        if grep -E 'torch\.cuda|device=.*cuda|import subprocess|from subprocess|import requests|import urllib' \
          ${./reference/rwkv7_torch_equation_reference.py}; then
          echo "PyTorch equation reference contains a GPU, subprocess, or network surface" >&2
          exit 1
        fi
        grep -Fq 'from fla.models.rwkv7' ${hfModelingSource}
        grep -Fq 'potentially buggy FLA implementation of RWKV' ${flaRwkv7Source}
        grep -Fq 'state = state * w' ${officialRwkvSource}

        for receipt_name in receipt-first.json receipt-second.json; do
          python ${./reference/rwkv7_torch_equation_reference.py} \
            --model ${model} \
            --rust-fixture rust-fixture-first.json \
            --hf-source ${hfModelingSource} \
            --fla-source ${flaRwkv7Source} \
            --official-source ${officialRwkvSource} \
            > "$receipt_name"
        done
        cmp receipt-first.json receipt-second.json
        cp receipt-first.json "$out/receipt.json"
        grep -Fq '"valid":true' "$out/receipt.json"
        grep -Fq '"top_two_token_ids_match":true' "$out/receipt.json"
        grep -Fq '"device":"cpu"' "$out/receipt.json"
        grep -Fq 'No FLA kernel/runtime parity is established.' "$out/receipt.json"
      '';
  observedLayerReplayCheck =
    runCommand "rwkv-ttwkv7-observed-layer-replay"
      {
        nativeBuildInputs = [
          b3sum
          nickel
        ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        replay=${package}/bin/rwkv-ttwkv7-observed-layer
        evidence=${observedEvidenceRoot}

        nickel export --format json ${./observed-layer-evidence.ncl} >typed-evidence.json
        test "$(b3sum typed-evidence.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedObservedTypedEvidenceBlake3}
        grep -F '"outcome": "unsafe"' typed-evidence.json
        grep -F '"terminal_classification_rewritten": false' typed-evidence.json
        grep -F '"owner_health_status": 200' typed-evidence.json

        "$replay" --evidence-root "$evidence" >replay-first.json
        "$replay" --evidence-root "$evidence" >replay-second.json
        cmp replay-first.json replay-second.json
        test "$(b3sum replay-first.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedObservedReplayBlake3}
        grep -F '"target": "rwkv_ttwkv7_observed_layer_replay"' replay-first.json
        grep -F '"terminal_outcome": "unsafe"' replay-first.json
        grep -F '"terminal_owner_health_status": null' replay-first.json
        grep -F '"device_initialized": true' replay-first.json
        grep -F '"workload_enqueue_count": 1' replay-first.json
        grep -F '"process_exit_status": 0' replay-first.json
        grep -F '"process_timed_out": false' replay-first.json
        grep -F '"evidence_bundle_blake3": "${expectedObservedEvidenceBundleBlake3}"' replay-first.json
        grep -F '"blake3": "${expectedSourceAttentionBlake3}"' replay-first.json
        grep -F '"blake3": "${expectedBf16BoundaryAttentionBlake3}"' replay-first.json
        grep -F '"blake3": "${expectedBf16BoundaryFinalLayerBlake3}"' replay-first.json
        grep -F '"blake3": "${expectedObservedAttentionBlake3}"' replay-first.json
        grep -F '"blake3": "${expectedObservedFinalLayerBlake3}"' replay-first.json
        grep -F '"observed_final_layer_output_vs_expected_bf16": ${expectedObservedFinalVsExpectedDeviation}' \
          replay-first.json
        grep -F '"observed_final_layer_output_vs_source_fp32": ${expectedObservedFinalVsSourceDeviation}' \
          replay-first.json
        grep -F 'No complete RWKV layer ran wholly on a Tenstorrent device.' replay-first.json
        grep -F 'No hardware-backed token generation is established.' replay-first.json

        test "$(wc -c <"$evidence/observed-output.bf16")" -eq ${toString observedOutputByteCount}
        test "$(wc -c <"$evidence/observed-post-state.bf16")" -eq ${toString observedPostStateByteCount}
        test "$(wc -c <"$evidence/writer-raw.bf16")" -eq ${toString writerRawByteCount}
        test ! -e ${package}/share/rwkv-layer-harness/ttwkv7-device-2

        expect_failure() {
          expected_diagnostic="$1"
          output_path="$2"
          shift 2
          if "$@" >"$output_path" 2>&1; then
            echo "observed-layer negative command unexpectedly passed: $*" >&2
            exit 1
          fi
          grep -F "$expected_diagnostic" "$output_path"
        }

        expect_failure 'usage: rwkv-ttwkv7-observed-layer --evidence-root PATH' \
          missing-arguments.log "$replay"
        expect_failure 'usage: rwkv-ttwkv7-observed-layer --evidence-root PATH' \
          extra-arguments.log "$replay" --evidence-root "$evidence" unexpected

        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf '\n' >>"$changed_root/classification-receipt.json"
        expect_failure 'classification receipt BLAKE3 mismatch' \
          changed-classification.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf '\n' >>"$changed_root/boundary-receipt.json"
        expect_failure 'boundary receipt BLAKE3 mismatch' \
          changed-receipt.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-output.bf16" bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed output BF16 BLAKE3 mismatch' \
          changed-output.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        head -c ${toString truncatedOutputByteCount} "$evidence/observed-output.bf16" \
          >"$changed_root/observed-output.bf16"
        expect_failure 'observed output BF16 BLAKE3 mismatch' \
          truncated-output.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-post-state.bf16" bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed post-state BF16 BLAKE3 mismatch' \
          changed-state.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/writer-raw.bf16" bs=1 seek=0 conv=notrunc status=none
        expect_failure 'writer raw BF16 BLAKE3 mismatch' \
          changed-writer.log "$replay" --evidence-root "$changed_root"

        test "$(grep -Fc 'wkv_step_matrix(' ${./src/observed_layer.rs})" -eq 2
        if grep -E 'std::process::Command|Command::new|MeshDevice|EnqueueMeshWorkload|TT_VISIBLE_DEVICES|tt-smi' \
          ${./src/observed_layer.rs} ${./src/bin/rwkv-ttwkv7-observed-layer.rs}; then
          echo "observed-layer replay contains a process or device execution surface" >&2
          exit 1
        fi
        test "$(grep -Fc 'finish_time_mix_attention(' ${./src/lib.rs})" -ge 3
        test "$(grep -Fc 'finish_layer_suffix(' ${./src/lib.rs})" -ge 3

        cp replay-first.json "$out/receipt.json"
        cp typed-evidence.json "$out/evidence.json"
      '';
  stateCarryCheck =
    runCommand "rwkv-ttwkv7-observed-state-carry"
      {
        nativeBuildInputs = [ b3sum ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        replay=${package}/bin/rwkv-ttwkv7-observed-layer
        carry=${package}/bin/rwkv-ttwkv7-observed-state-carry
        evidence=${observedEvidenceRoot}

        "$replay" --evidence-root "$evidence" >observed-layer.json
        test "$(b3sum observed-layer.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedObservedReplayBlake3}

        "$carry" --evidence-root "$evidence" >carry-first.json
        "$carry" --evidence-root "$evidence" >carry-second.json
        cmp carry-first.json carry-second.json
        test "$(b3sum carry-first.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedStateCarryReplayBlake3}
        grep -F '"target": "rwkv_ttwkv7_observed_state_carry"' carry-first.json
        grep -F '"token_ids": [' carry-first.json
        grep -F '"observed_layer_receipt_blake3": "${expectedObservedReplayBlake3}"' \
          carry-first.json
        grep -F '"terminal_session_outcome": "unsafe"' carry-first.json
        grep -F '"evidence_bundle_blake3": "${expectedObservedEvidenceBundleBlake3}"' \
          carry-first.json
        grep -F '"physical_seed_post_state_blake3": "b3321aeb38963fb96a720ae33d9477e8fbfb83b3750213abc64786885d3771a9"' \
          carry-first.json
        test "$(grep -Fc '"wkv_executor": "cpu_matrix_recurrence"' carry-first.json)" -eq 5
        test "$(grep -Fc '"transport_precision": "bf16_round_trip_around_cpu_fp32"' carry-first.json)" -eq 4
        for expected_blake3 in \
          ${
            lib.escapeShellArgs [
              expectedStateCarrySourcePostStateBlake3
              expectedStateCarrySourceFinalBlake3
              expectedStateCarryBf16PostStateBlake3
              expectedStateCarryBf16FinalBlake3
              expectedStateCarryObservedPreStateBlake3
              expectedStateCarryObservedRawBlake3
              expectedStateCarryObservedPostStateBlake3
              expectedStateCarryObservedFinalBlake3
              expectedStateCarryResetPostStateBlake3
              expectedStateCarryResetFinalBlake3
              expectedStateCarryTransposedPreStateBlake3
              expectedStateCarryTransposedPostStateBlake3
              expectedStateCarryTransposedFinalBlake3
            ]
          }; do
          grep -F "\"blake3\": \"$expected_blake3\"" carry-first.json
        done
        grep -F '"observed_raw_output_vs_expected_bf16": ${expectedStateCarryObservedVsExpectedRawDeviation}' \
          carry-first.json
        grep -F '"observed_post_state_vs_expected_bf16": ${expectedStateCarryObservedVsExpectedStateDeviation}' \
          carry-first.json
        grep -F '"observed_final_layer_output_vs_expected_bf16": ${expectedStateCarryObservedVsExpectedFinalDeviation}' \
          carry-first.json
        grep -F '"observed_post_state_vs_reset_state": ${expectedStateCarryResetStateDivergence}' \
          carry-first.json
        grep -F '"observed_final_layer_output_vs_reset_state": ${expectedStateCarryResetOutputDivergence}' \
          carry-first.json
        grep -F '"observed_post_state_vs_transposed_state": ${expectedStateCarryTransposedStateDivergence}' \
          carry-first.json
        grep -F '"observed_final_layer_output_vs_transposed_state": ${expectedStateCarryTransposedOutputDivergence}' \
          carry-first.json
        grep -F 'The next recurrent WKV step is executed by the CPU equation, not physical hardware.' \
          carry-first.json
        grep -F 'No hardware-backed token generation is established.' carry-first.json

        expect_failure() {
          expected_diagnostic="$1"
          output_path="$2"
          shift 2
          if "$@" >"$output_path" 2>&1; then
            echo "state-carry negative command unexpectedly passed: $*" >&2
            exit 1
          fi
          grep -F "$expected_diagnostic" "$output_path"
        }

        expect_failure 'usage: rwkv-ttwkv7-observed-state-carry --evidence-root PATH' \
          missing-arguments.log "$carry"
        expect_failure 'usage: rwkv-ttwkv7-observed-state-carry --evidence-root PATH' \
          extra-arguments.log "$carry" --evidence-root "$evidence" unexpected
        expect_failure 'usage: rwkv-ttwkv7-observed-state-carry --evidence-root PATH' \
          reordered-arguments.log "$carry" "$evidence" --evidence-root

        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf '\n' >>"$changed_root/classification-receipt.json"
        expect_failure 'classification receipt BLAKE3 mismatch' \
          changed-classification.log "$carry" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-post-state.bf16" \
          bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed post-state BF16 BLAKE3 mismatch' \
          changed-state.log "$carry" --evidence-root "$changed_root"

        test ! -e ${package}/share/rwkv-layer-harness/ttwkv7-device-2
        if grep -E 'std::process::Command|Command::new|MeshDevice|EnqueueMeshWorkload|TT_VISIBLE_DEVICES|tt-smi' \
          ${./src/observed_layer.rs} ${./src/bin/rwkv-ttwkv7-observed-state-carry.rs}; then
          echo "state-carry replay contains a process or device execution surface" >&2
          exit 1
        fi
        test "$(grep -Fc 'wkv_step_matrix(' ${./src/observed_layer.rs})" -eq 2
        test "$(grep -Fc 'next[index] = state[index]' ${./src/lib.rs})" -eq 1

        cp carry-first.json "$out/receipt.json"
      '';
  modelCarryCheck =
    runCommand "rwkv-ttwkv7-observed-model-carry"
      {
        nativeBuildInputs = [ b3sum ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        replay=${package}/bin/rwkv-ttwkv7-observed-model-carry
        evidence=${observedEvidenceRoot}

        "$replay" --evidence-root "$evidence" >model-first.json
        "$replay" --evidence-root "$evidence" >model-second.json
        cmp model-first.json model-second.json
        test "$(b3sum model-first.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedModelCarryReplayBlake3}
        test "$(wc -c <model-first.json)" -eq ${toString expectedModelCarryReceiptByteCount}
        grep -F '"target": "rwkv_ttwkv7_observed_model_carry"' model-first.json
        grep -F '"layer_count": 12' model-first.json
        grep -F '"physical_evidence_layer_index": 0' model-first.json
        grep -F '"physical_evidence_token_ordinal": 2' model-first.json
        grep -F '"physical_wkv_call_count": 1' model-first.json
        grep -F '"cpu_second_token_layer_count": 11' model-first.json
        grep -F '"cpu_third_token_layer_count": 12' model-first.json
        grep -F '"observed_layer_receipt_blake3": "${expectedObservedReplayBlake3}"' \
          model-first.json
        grep -F '"observed_state_carry_receipt_blake3": "${expectedStateCarryReplayBlake3}"' \
          model-first.json
        grep -F '"terminal_session_outcome": "unsafe"' model-first.json
        grep -F '"evidence_bundle_blake3": "${expectedObservedEvidenceBundleBlake3}"' \
          model-first.json
        test "$(grep -Fc '"third_token_layer_outputs": [' model-first.json)" -eq 5
        test "$(grep -Fc '"generated_token_id": 2' model-first.json)" -eq 5
        test "$(grep -Fc '"runner_up_token_id": 33' model-first.json)" -eq 5
        test "$(grep -Fc '"direct_bf16_head_deviation": 0.0' model-first.json)" -eq 5

        for expected_blake3 in \
          ${
            lib.escapeShellArgs (
              expectedModelCarrySourceBlake3
              ++ expectedModelCarryBf16Blake3
              ++ expectedModelCarryObservedBlake3
              ++ expectedModelCarryResetBlake3
              ++ expectedModelCarryTransposedBlake3
            )
          }; do
          grep -F "\"blake3\": \"$expected_blake3\"" model-first.json
        done
        grep -F '"observed_logits_vs_expected_bf16": ${expectedModelCarryObservedVsExpectedLogitsDeviation}' \
          model-first.json
        grep -F '"observed_complete_state_vs_expected_bf16": ${expectedModelCarryObservedVsExpectedStateDeviation}' \
          model-first.json
        grep -F '"observed_logits_vs_reset_state": ${expectedModelCarryResetLogitsDivergence}' \
          model-first.json
        grep -F '"observed_complete_state_vs_reset_state": ${expectedModelCarryResetStateDivergence}' \
          model-first.json
        grep -F '"observed_logits_vs_transposed_state": ${expectedModelCarryTransposedLogitsDivergence}' \
          model-first.json
        grep -F '"observed_complete_state_vs_transposed_state": ${expectedModelCarryTransposedStateDivergence}' \
          model-first.json
        grep -F 'Only the accepted layer-zero second-token WKV output and post-state came from physical execution.' \
          model-first.json
        grep -F 'The third-token layer-zero WKV step is executed by the CPU equation with BF16 transport emulation.' \
          model-first.json
        grep -F 'The selected logits do not establish hardware-backed token generation.' \
          model-first.json

        expect_failure() {
          expected_diagnostic="$1"
          output_path="$2"
          shift 2
          if "$@" >"$output_path" 2>&1; then
            echo "observed-model negative command unexpectedly passed: $*" >&2
            exit 1
          fi
          grep -F "$expected_diagnostic" "$output_path"
        }

        expect_failure 'usage: rwkv-ttwkv7-observed-model-carry --evidence-root PATH' \
          missing-arguments.log "$replay"
        expect_failure 'usage: rwkv-ttwkv7-observed-model-carry --evidence-root PATH' \
          extra-arguments.log "$replay" --evidence-root "$evidence" unexpected
        expect_failure 'usage: rwkv-ttwkv7-observed-model-carry --evidence-root PATH' \
          reordered-arguments.log "$replay" "$evidence" --evidence-root

        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf '\n' >>"$changed_root/classification-receipt.json"
        expect_failure 'classification receipt BLAKE3 mismatch' \
          changed-classification.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-output.bf16" \
          bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed output BF16 BLAKE3 mismatch' \
          changed-output.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-post-state.bf16" \
          bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed post-state BF16 BLAKE3 mismatch' \
          changed-state.log "$replay" --evidence-root "$changed_root"

        test ! -e ${package}/share/rwkv-layer-harness/ttwkv7-device-2
        test "$(grep -Fc 'for (layer_index, layer) in weights.iter().enumerate()' \
          ${./src/lib.rs})" -ge 2
        test "$(grep -Fc 'LayerZeroWkvMode::Observed' ${./src/lib.rs})" -eq 1
        if grep -E 'std::process::Command|Command::new|MeshDevice|EnqueueMeshWorkload|TT_VISIBLE_DEVICES|tt-smi' \
          ${./src/observed_layer.rs} ${./src/bin/rwkv-ttwkv7-observed-model-carry.rs}; then
          echo "observed-model replay contains a process or device execution surface" >&2
          exit 1
        fi

        cp model-first.json "$out/receipt.json"
      '';
  modelDispatchCheck =
    runCommand "rwkv-ttwkv7-observed-model-dispatch"
      {
        nativeBuildInputs = [ b3sum ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        replay=${package}/bin/rwkv-ttwkv7-observed-model-dispatch
        evidence=${observedEvidenceRoot}

        "$replay" --evidence-root "$evidence" >dispatch-first.json
        "$replay" --evidence-root "$evidence" >dispatch-second.json
        cmp dispatch-first.json dispatch-second.json
        test "$(b3sum dispatch-first.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedModelDispatchReplayBlake3}
        test "$(wc -c <dispatch-first.json)" -eq \
          ${toString expectedModelDispatchReceiptByteCount}
        grep -F '"target": "rwkv_ttwkv7_observed_model_dispatch"' dispatch-first.json
        grep -F '"dispatched_token_index_zero_based": 2' dispatch-first.json
        grep -F '"dispatch_call_count": 12' dispatch-first.json
        grep -F '"physical_wkv_call_count": 1' dispatch-first.json
        grep -F '"new_physical_wkv_call_count": 0' dispatch-first.json
        grep -F '"observed_model_carry_receipt_blake3": "${expectedModelCarryReplayBlake3}"' \
          dispatch-first.json
        grep -F '"dispatch_abi_receipt_blake3": "${expectedDispatchAbiReplayBlake3}"' \
          dispatch-first.json
        grep -F '"terminal_session_outcome": "unsafe"' dispatch-first.json
        grep -F '"evidence_bundle_blake3": "${expectedObservedEvidenceBundleBlake3}"' \
          dispatch-first.json
        test "$(grep -Fc '"request_frame_byte_count": 107588' dispatch-first.json)" -eq 3
        test "$(grep -Fc '"response_frame_byte_count": 99940' dispatch-first.json)" -eq 3
        test "$(grep -Fc '"third_token_layer_outputs": [' dispatch-first.json)" -eq 4
        test "$(grep -Ec '^        "[0-9a-f]{64}"[, ]*$' dispatch-first.json)" -eq 72
        test "$(grep -Fc '"generated_token_id": 2' dispatch-first.json)" -eq 2
        test "$(grep -Fc '"runner_up_token_id": 33' dispatch-first.json)" -eq 2
        grep -F '"generated_token_id": 92' dispatch-first.json
        grep -F '"runner_up_token_id": 11' dispatch-first.json
        grep -F '"generated_token_id": 47' dispatch-first.json
        grep -F '"runner_up_token_id": 1753' dispatch-first.json
        for expected in ${lib.escapeShellArgs expectedModelDispatchTranscripts}; do
          grep -F "\"transcript_blake3\": \"$expected\"" dispatch-first.json
        done
        for expected in ${lib.escapeShellArgs expectedModelDispatchSequenceIds}; do
          grep -F "\"sequence_id\": \"$expected\"" dispatch-first.json
        done
        for expected in ${
          lib.escapeShellArgs (expectedModelDispatchSeedBlake3 ++ expectedModelDispatchPathBlake3)
        }; do
          grep -F "\"blake3\": \"$expected\"" dispatch-first.json
        done
        for expected in ${lib.escapeShellArgs expectedModelDispatchOracleDeviations}; do
          grep -F ": $expected" dispatch-first.json
        done
        for expected in ${lib.escapeShellArgs expectedModelDispatchControlDivergences}; do
          grep -F ": $expected" dispatch-first.json
        done
        grep -F '"oracle_tolerance": 0.002' dispatch-first.json
        grep -F 'All twelve third-token WKV calls execute in the device-free CPU dispatcher.' \
          dispatch-first.json
        grep -F 'No new hardware execution is authorized by this replay.' dispatch-first.json

        expect_failure() {
          expected_diagnostic="$1"
          output_path="$2"
          shift 2
          if "$@" >"$output_path" 2>&1; then
            echo "model-dispatch negative command unexpectedly passed: $*" >&2
            exit 1
          fi
          grep -F "$expected_diagnostic" "$output_path"
        }
        usage='usage: rwkv-ttwkv7-observed-model-dispatch --evidence-root PATH'
        expect_failure "$usage" missing-arguments.log "$replay"
        expect_failure "$usage" extra-arguments.log \
          "$replay" --evidence-root "$evidence" unexpected
        expect_failure "$usage" reordered-arguments.log \
          "$replay" "$evidence" --evidence-root

        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf '\n' >>"$changed_root/classification-receipt.json"
        expect_failure 'classification receipt BLAKE3 mismatch' \
          changed-classification.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-post-state.bf16" \
          bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed post-state BF16 BLAKE3 mismatch' \
          changed-state.log "$replay" --evidence-root "$changed_root"

        if grep -E 'std::process::Command|Command::new|MeshDevice::|EnqueueMeshWorkload|TT_VISIBLE_DEVICES' \
          ${./src/dispatch_abi.rs} ${./src/observed_layer.rs} \
          ${./src/bin/rwkv-ttwkv7-observed-model-dispatch.rs}; then
          echo "model dispatch contains a process or device execution surface" >&2
          exit 1
        fi
        test ! -e ${package}/share/rwkv-layer-harness/ttwkv7-device-2
        cp dispatch-first.json "$out/receipt.json"
      '';
  persistentModelDispatchCheck =
    runCommand "rwkv-ttwkv7-persistent-observed-model-dispatch"
      {
        nativeBuildInputs = [ b3sum ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        replay=${package}/bin/rwkv-ttwkv7-persistent-model-dispatch
        evidence=${observedEvidenceRoot}

        "$replay" --evidence-root "$evidence" >persistent-first.json
        "$replay" --evidence-root "$evidence" >persistent-second.json
        cmp persistent-first.json persistent-second.json
        test "$(b3sum persistent-first.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedPersistentModelDispatchReplayBlake3}
        test "$(wc -c <persistent-first.json)" -eq \
          ${toString expectedPersistentModelDispatchReceiptByteCount}
        grep -F '"target": "rwkv_ttwkv7_persistent_observed_model_dispatch"' \
          persistent-first.json
        grep -F '"token_ids": [' persistent-first.json
        grep -F '"dispatched_token_indices_zero_based": [' persistent-first.json
        grep -F '"dispatch_call_count": 24' persistent-first.json
        grep -F '"physical_wkv_call_count": 1' persistent-first.json
        grep -F '"new_physical_wkv_call_count": 0' persistent-first.json
        grep -F '"prior_model_dispatch_receipt_blake3": "${expectedModelDispatchReplayBlake3}"' \
          persistent-first.json
        grep -F '"terminal_session_outcome": "unsafe"' persistent-first.json
        grep -F '"evidence_bundle_blake3": "${expectedObservedEvidenceBundleBlake3}"' \
          persistent-first.json
        grep -F '"selected_fourth_token_id": 2' persistent-first.json
        test "$(grep -Fc '"call_count": 24' persistent-first.json)" -eq 3
        test "$(grep -Fc '"same_layer_state_continuity_count": 12' \
          persistent-first.json)" -eq 3
        test "$(grep -Fc '"request_frame_byte_count": 107588' \
          persistent-first.json)" -eq 3
        test "$(grep -Fc '"response_frame_byte_count": 99940' \
          persistent-first.json)" -eq 3
        test "$(grep -Fc '"terminal_state": "closed"' persistent-first.json)" -eq 3
        test "$(grep -Ec '^        "[0-9a-f]{64}"[, ]*$' persistent-first.json)" -eq 144
        test "$(grep -Fc '"generated_token_id": 2' persistent-first.json)" -eq 4
        test "$(grep -Fc '"runner_up_token_id": 33' persistent-first.json)" -eq 4
        for expected in ${lib.escapeShellArgs expectedPersistentModelDispatchSequenceIds}; do
          grep -F "\"sequence_id\": \"$expected\"" persistent-first.json
        done
        for expected in ${lib.escapeShellArgs expectedPersistentModelDispatchTranscripts}; do
          grep -F "\"transcript_blake3\": \"$expected\"" persistent-first.json
        done
        for expected in ${lib.escapeShellArgs expectedModelDispatchSeedBlake3}; do
          grep -F "\"blake3\": \"$expected\"" persistent-first.json
        done
        for expected in ${lib.escapeShellArgs expectedPersistentModelDispatchFourthTokenBlake3}; do
          grep -F "\"blake3\": \"$expected\"" persistent-first.json
        done
        for expected in ${lib.escapeShellArgs expectedPersistentModelDispatchOracleDeviations}; do
          grep -F ": $expected" persistent-first.json
        done
        for expected in ${lib.escapeShellArgs expectedPersistentModelDispatchControlDivergences}; do
          grep -F ": $expected" persistent-first.json
        done
        grep -F '"oracle_tolerance": 0.005' persistent-first.json
        grep -F 'The persistent session is a pure in-memory lifecycle contract, not an operating-system process.' \
          persistent-first.json
        grep -F 'No child process, socket, retry, backoff, reconnect, or persistent Metalium transport is established.' \
          persistent-first.json
        grep -F 'Tasks 30 and 64 remain terminal and are not reusable.' persistent-first.json
        grep -F 'No new hardware execution is authorized by this replay.' persistent-first.json

        expect_failure() {
          expected_diagnostic="$1"
          output_path="$2"
          shift 2
          if "$@" >"$output_path" 2>&1; then
            echo "persistent model-dispatch negative command unexpectedly passed: $*" >&2
            exit 1
          fi
          grep -F "$expected_diagnostic" "$output_path"
        }
        usage='usage: rwkv-ttwkv7-persistent-model-dispatch --evidence-root PATH'
        expect_failure "$usage" missing-arguments.log "$replay"
        expect_failure "$usage" extra-arguments.log \
          "$replay" --evidence-root "$evidence" unexpected
        expect_failure "$usage" reordered-arguments.log \
          "$replay" "$evidence" --evidence-root

        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf '\n' >>"$changed_root/classification-receipt.json"
        expect_failure 'classification receipt BLAKE3 mismatch' \
          changed-classification.log "$replay" --evidence-root "$changed_root"

        rm -rf "$changed_root"
        changed_root="$(mktemp -d)"
        cp -R "$evidence/." "$changed_root/"
        chmod -R u+w "$changed_root"
        printf 'x' | dd of="$changed_root/observed-post-state.bf16" \
          bs=1 seek=0 conv=notrunc status=none
        expect_failure 'observed post-state BF16 BLAKE3 mismatch' \
          changed-state.log "$replay" --evidence-root "$changed_root"

        for required_test in \
          persistent_session_completes_two_tokens_with_same_layer_state_continuity \
          persistent_session_rejects_order_and_same_layer_state_drift \
          persistent_session_rejects_stale_truncated_and_duplicate_responses \
          persistent_session_rejects_parallel_pending_calls_and_extra_calls \
          persistent_session_timeout_interruption_and_premature_close_are_terminal; do
          grep -F "fn $required_test" ${./src/dispatch_abi.rs}
        done
        if grep -E 'std::process::Command|Command::new|UnixStream|TcpStream|MeshDevice::|EnqueueMeshWorkload|TT_VISIBLE_DEVICES' \
          ${./src/dispatch_abi.rs} ${./src/observed_layer.rs} \
          ${./src/bin/rwkv-ttwkv7-persistent-model-dispatch.rs}; then
          echo "persistent model dispatch contains a process, socket, or device execution surface" >&2
          exit 1
        fi
        test ! -e ${package}/share/rwkv-layer-harness/ttwkv7-device-2
        cp persistent-first.json "$out/receipt.json"
      '';
  dispatchAbiCheck =
    runCommand "rwkv-ttwkv7-dispatch-abi"
      {
        nativeBuildInputs = [ b3sum ];
      }
      ''
        set -euo pipefail
        mkdir -p "$out"
        replay=${package}/bin/rwkv-ttwkv7-dispatch-abi

        "$replay" >dispatch-first.json
        "$replay" >dispatch-second.json
        cmp dispatch-first.json dispatch-second.json
        test "$(b3sum dispatch-first.json | cut -d' ' -f1)" = \
          ${lib.escapeShellArg expectedDispatchAbiReplayBlake3}
        test "$(wc -c <dispatch-first.json)" -eq \
          ${toString expectedDispatchAbiReceiptByteCount}
        grep -F '"target": "rwkv_ttwkv7_dispatch_abi"' dispatch-first.json
        grep -F '"layer_count": 12' dispatch-first.json
        grep -F '"token_count": 2' dispatch-first.json
        grep -F '"call_count": 24' dispatch-first.json
        grep -F '"input_order": [' dispatch-first.json
        for role in a w k v r b; do
          grep -F "\"$role\"" dispatch-first.json
        done
        grep -F '"request_frame_byte_count": 107588' dispatch-first.json
        grep -F '"response_frame_byte_count": 99940' dispatch-first.json
        grep -F '"sequence_id_blake3": "${expectedDispatchAbiSequenceBlake3}"' \
          dispatch-first.json
        grep -F '"transcript_blake3": "${expectedDispatchAbiTranscriptBlake3}"' \
          dispatch-first.json
        grep -F '"retained_final_state_blake3": "${expectedDispatchAbiRetainedStateBlake3}"' \
          dispatch-first.json
        grep -F '"reset_final_state_blake3": "${expectedDispatchAbiResetStateBlake3}"' \
          dispatch-first.json
        grep -F '"transposed_final_state_blake3": "${expectedDispatchAbiTransposedStateBlake3}"' \
          dispatch-first.json
        grep -F '"retained_vs_reset_maximum_absolute_deviation": ${expectedDispatchAbiResetDivergence}' \
          dispatch-first.json
        grep -F '"retained_vs_transposed_maximum_absolute_deviation": ${expectedDispatchAbiTransposedDivergence}' \
          dispatch-first.json
        grep -F '"terminal_session_outcome": "unsafe"' dispatch-first.json
        grep -F '"physical_wkv_call_count": 0' dispatch-first.json
        test "$(grep -Ec '^    "[0-9a-f]{64}"[, ]*$' dispatch-first.json)" -eq 48
        grep -F 'The dispatch vectors are deterministic ABI fixtures, not model-derived vectors.' \
          dispatch-first.json
        grep -F 'No new hardware execution is authorized by this receipt.' \
          dispatch-first.json

        if "$replay" unexpected >argument-rejection.log 2>&1; then
          echo "dispatch ABI replay accepted an argument" >&2
          exit 1
        fi
        grep -F 'rwkv-ttwkv7-dispatch-abi accepts no arguments' argument-rejection.log

        if grep -E 'std::process::Command|Command::new|MeshDevice|EnqueueMeshWorkload|/dev/tenstorrent|TT_VISIBLE_DEVICES|tt-smi' \
          ${./src/dispatch_abi.rs} ${./src/bin/rwkv-ttwkv7-dispatch-abi.rs}; then
          echo "dispatch ABI replay contains a process or device execution surface" >&2
          exit 1
        fi
        test ! -e ${package}/share/rwkv-layer-harness/ttwkv7-device-2
        cp dispatch-first.json "$out/receipt.json"
      '';
  package = rustPlatform.buildRustPackage {
    pname = "rwkv-layer-harness";
    version = "0.1.0";

    src = lib.cleanSource ./.;
    cargoLock.lockFile = ./Cargo.lock;

    RWKV_LAYER_MODEL = model;
    RWKV_LAYER_MODEL_BLAKE3 = modelBlake3;
    RWKV_TOKENIZER_VOCABULARY = tokenizerVocabulary;
    RWKV_TOKENIZER_CONFIG = tokenizerConfig;
    RWKV_TOKENIZER_ADDED_TOKENS = addedTokens;
    RWKV_TOKENIZER_IMPLEMENTATION = tokenizerImplementation;
    RWKV_SPECIAL_TOKENS_MAP = specialTokensMap;
    RWKV_MODEL_CONFIG = modelConfig;
    RWKV_GENERATION_CONFIG = generationConfig;

    postInstall = ''
      mkdir -p "$out/share/rwkv-layer-harness"
      "$out/bin/rwkv-ttwkv7-fixture" \
        >"$out/share/rwkv-layer-harness/ttwkv7-boundary.json"
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      set -euo pipefail

      fixture_root="$(mktemp -d)"
      $out/bin/rwkv-layer-harness >"$fixture_root/first.json"
      $out/bin/rwkv-layer-harness >"$fixture_root/second.json"
      cmp "$fixture_root/first.json" "$fixture_root/second.json"

      grep -F '"model_id": "RWKV/RWKV7-Goose-World2.8-0.1B-HF"' "$fixture_root/first.json"
      grep -F '"revision": "${modelRevision}"' "$fixture_root/first.json"
      grep -F '"blake3": "${modelBlake3}"' "$fixture_root/first.json"
      grep -F '"hidden_size": 768' "$fixture_root/first.json"
      grep -F '"head_size": 64' "$fixture_root/first.json"
      grep -F '"head_count": 12' "$fixture_root/first.json"
      grep -F '"intermediate_size": 3072' "$fixture_root/first.json"
      grep -F '"token_ids": [' "$fixture_root/first.json"
      grep -F '"arithmetic_precision": "cpu_fp32_from_bf16"' "$fixture_root/first.json"
      grep -F '"finite": true' "$fixture_root/first.json"
      grep -F '"maximum_oracle_state_deviation":' "$fixture_root/first.json"
      grep -F '"maximum_oracle_output_deviation":' "$fixture_root/first.json"
      for expected_fingerprint in ${lib.escapeShellArgs expectedSecondTokenFingerprints}; do
        grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/first.json"
      done
      grep -F '"blake3": "${expectedFinalStateFingerprint}"' "$fixture_root/first.json"
      grep -F '"blake3": "${expectedFinalOutputFingerprint}"' "$fixture_root/first.json"
      grep -F 'No generated token is established.' "$fixture_root/first.json"

      $out/bin/rwkv-token-harness >"$fixture_root/token-first.json"
      $out/bin/rwkv-token-harness >"$fixture_root/token-second.json"
      cmp "$fixture_root/token-first.json" "$fixture_root/token-second.json"
      grep -F '"layer_count": ${toString expectedModelLayerCount}' "$fixture_root/token-first.json"
      grep -F '"prefix_token_ids": [' "$fixture_root/token-first.json"
      grep -F '"generated_token_id": ${toString expectedGeneratedTokenId}' "$fixture_root/token-first.json"
      grep -F '"generated_logit": ${expectedGeneratedLogit}' "$fixture_root/token-first.json"
      grep -F '"runner_up_token_id": ${toString expectedRunnerUpTokenId}' "$fixture_root/token-first.json"
      grep -F '"runner_up_logit": ${expectedRunnerUpLogit}' "$fixture_root/token-first.json"
      grep -F '"greedy_margin": ${expectedGreedyMargin}' "$fixture_root/token-first.json"
      grep -F '"blake3": "${expectedTokenFinalHiddenFingerprint}"' "$fixture_root/token-first.json"
      grep -F '"blake3": "${expectedTokenLogitsFingerprint}"' "$fixture_root/token-first.json"
      grep -F '"blake3": "${expectedTokenStatesFingerprint}"' "$fixture_root/token-first.json"
      grep -F '"head_oracle_logit_deviation": 0.0' "$fixture_root/token-first.json"
      grep -F 'The selected token is not executed as a recurrent third step.' "$fixture_root/token-first.json"
      grep -F 'No P150 numerical parity is established.' "$fixture_root/token-first.json"

      $out/bin/rwkv-decode-harness >"$fixture_root/decode-first.json"
      $out/bin/rwkv-decode-harness >"$fixture_root/decode-second.json"
      cmp "$fixture_root/decode-first.json" "$fixture_root/decode-second.json"
      grep -F '"seed_token_id": ${toString expectedDecodeTokenId}' "$fixture_root/decode-first.json"
      grep -F '"generated_step_count": ${toString expectedDecodeStepCount}' "$fixture_root/decode-first.json"
      generated_count="$(grep -c '"generated_token_id": ${toString expectedDecodeTokenId}' "$fixture_root/decode-first.json")"
      test "$generated_count" -eq ${toString expectedDecodeStepCount}
      for expected_logit in ${lib.escapeShellArgs expectedDecodeLogits}; do
        grep -F "\"generated_logit\": $expected_logit" "$fixture_root/decode-first.json"
      done
      for expected_fingerprint in ${lib.escapeShellArgs expectedDecodeFingerprints}; do
        grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/decode-first.json"
      done
      grep -F '"maximum_replay_hidden_deviation": 0.0' "$fixture_root/decode-first.json"
      grep -F '"maximum_replay_logits_deviation": 0.0' "$fixture_root/decode-first.json"
      grep -F '"maximum_replay_state_deviation": 0.0' "$fixture_root/decode-first.json"
      grep -F '"minimum_retained_vs_reset_hidden_deviation": ${expectedMinimumStateCarryDivergence}' "$fixture_root/decode-first.json"
      grep -F '"model_config_eos_token_id": 2' "$fixture_root/decode-first.json"
      grep -F '"continued_after_model_config_eos": false' "$fixture_root/decode-first.json"
      grep -F 'No decoded text or tokenizer mapping is established.' "$fixture_root/decode-first.json"

      $out/bin/rwkv-text-harness >"$fixture_root/text-first.json"
      $out/bin/rwkv-text-harness >"$fixture_root/text-second.json"
      cmp "$fixture_root/text-first.json" "$fixture_root/text-second.json"
      grep -F '"vocabulary_entry_count": 65529' "$fixture_root/text-first.json"
      grep -F '"model_config_bos_token_id": 1' "$fixture_root/text-first.json"
      grep -F '"model_config_eos_token_id": 2' "$fixture_root/text-first.json"
      grep -F '"tokenizer_bos_token_id": 0' "$fixture_root/text-first.json"
      grep -F '"byte_vocabulary_eos_token_id": 261' "$fixture_root/text-first.json"
      grep -F '"tokenizer_wrapper_eos_token_id": 65530' "$fixture_root/text-first.json"
      grep -F '"generation_config_bos_token_id": 0' "$fixture_root/text-first.json"
      grep -F '"generation_config_eos_token_id": 0' "$fixture_root/text-first.json"
      for expected_blake3 in ${lib.escapeShellArgs expectedTokenizerBlake3}; do
        grep -F "\"blake3\": \"$expected_blake3\"" "$fixture_root/text-first.json"
      done
      for fixture_name in empty tokenizer_eos overlapping_prefix ascii unicode control_bytes byte_fixed_chat_prompt wrapper_fixed_chat_prompt; do
        grep -F "\"name\": \"$fixture_name\"" "$fixture_root/text-first.json"
      done
      grep -F '"prompt_token_ids_blake3": "${expectedTextPromptIdsBlake3}"' "$fixture_root/text-first.json"
      grep -F '"generated_token_ids_blake3": "${expectedTextGeneratedIdsBlake3}"' "$fixture_root/text-first.json"
      grep -F '"generated_bytes_hex": "2048692c2049"' "$fixture_root/text-first.json"
      grep -F '"generated_text": " Hi, I"' "$fixture_root/text-first.json"
      grep -F '"stop_reason": "generation_step_limit"' "$fixture_root/text-first.json"
      for expected_token_id in ${lib.escapeShellArgs (map toString expectedTextGeneratedTokenIds)}; do
        grep -F "\"generated_token_id\": $expected_token_id" "$fixture_root/text-first.json"
      done
      for expected_logit in ${lib.escapeShellArgs expectedTextGeneratedLogits}; do
        grep -F "\"generated_logit\": $expected_logit" "$fixture_root/text-first.json"
      done
      for expected_fingerprint in ${lib.escapeShellArgs expectedTextFingerprints}; do
        grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/text-first.json"
      done
      grep -F '"maximum_replay_hidden_deviation": 0.0' "$fixture_root/text-first.json"
      grep -F '"maximum_replay_state_deviation": 0.0' "$fixture_root/text-first.json"
      grep -F '"minimum_retained_vs_reset_hidden_deviation": ${expectedTextStateCarryDivergence}' "$fixture_root/text-first.json"
      grep -F 'No P150 numerical parity is established.' "$fixture_root/text-first.json"

      $out/bin/rwkv-prompt-harness \
        --message Hello \
        --max-prompt-tokens ${toString promptMaxTokenCount} \
        --max-new-tokens ${toString promptFixtureNewTokenCount} \
        >"$fixture_root/prompt-first.json"
      $out/bin/rwkv-prompt-harness \
        --max-new-tokens ${toString promptFixtureNewTokenCount} \
        --message Hello \
        --max-prompt-tokens ${toString promptMaxTokenCount} \
        >"$fixture_root/prompt-second.json"
      cmp "$fixture_root/prompt-first.json" "$fixture_root/prompt-second.json"
      grep -F '"user_message": "Hello"' "$fixture_root/prompt-first.json"
      grep -F '"user_message_blake3": "${expectedPromptUserMessageBlake3}"' "$fixture_root/prompt-first.json"
      grep -F '"rendered_chat_prompt_blake3": "${expectedPromptRenderedBlake3}"' "$fixture_root/prompt-first.json"
      grep -F '"prompt_token_ids_blake3": "${expectedPromptIdsBlake3}"' "$fixture_root/prompt-first.json"
      grep -F '"generated_token_ids_blake3": "${expectedPromptGeneratedIdsBlake3}"' "$fixture_root/prompt-first.json"
      grep -F '"package_max_message_bytes": ${toString promptMaxMessageBytes}' "$fixture_root/prompt-first.json"
      grep -F '"package_max_prompt_tokens": ${toString promptMaxTokenCount}' "$fixture_root/prompt-first.json"
      grep -F '"package_max_new_tokens": ${toString promptMaxNewTokenCount}' "$fixture_root/prompt-first.json"
      grep -F '"max_new_tokens": ${toString promptFixtureNewTokenCount}' "$fixture_root/prompt-first.json"
      grep -F '"generated_token_limit": ${toString promptFixtureNewTokenCount}' "$fixture_root/prompt-first.json"
      grep -F '"generated_bytes_hex": "2048656c6c6f212049"' "$fixture_root/prompt-first.json"
      grep -F '"generated_utf8_complete": true' "$fixture_root/prompt-first.json"
      grep -F '"generated_text": " Hello! I"' "$fixture_root/prompt-first.json"
      for expected_token_id in ${lib.escapeShellArgs (map toString expectedPromptGeneratedTokenIds)}; do
        grep -F "\"generated_token_id\": $expected_token_id" "$fixture_root/prompt-first.json"
      done
      for expected_logit in ${lib.escapeShellArgs expectedPromptGeneratedLogits}; do
        grep -F "\"generated_logit\": $expected_logit" "$fixture_root/prompt-first.json"
      done
      for expected_fingerprint in ${lib.escapeShellArgs expectedPromptFingerprints}; do
        grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/prompt-first.json"
      done
      grep -F '"maximum_replay_hidden_deviation": 0.0' "$fixture_root/prompt-first.json"
      grep -F '"maximum_replay_state_deviation": 0.0' "$fixture_root/prompt-first.json"
      grep -F '"minimum_retained_vs_reset_hidden_deviation": ${expectedPromptStateCarryDivergence}' "$fixture_root/prompt-first.json"
      grep -F 'No FLA kernel/runtime or Transformers generation parity is established.' "$fixture_root/prompt-first.json"

      if $out/bin/rwkv-prompt-harness \
        --message Hello \
        --max-prompt-tokens ${toString promptMaxTokenCount} \
        >"$fixture_root/prompt-missing-limit.log" 2>&1; then
        echo "rwkv-prompt-harness accepted a missing generation limit" >&2
        exit 1
      fi
      grep -F 'requires --message TEXT --max-prompt-tokens COUNT --max-new-tokens COUNT' \
        "$fixture_root/prompt-missing-limit.log"

      if $out/bin/rwkv-prompt-harness \
        --message Hello \
        --max-prompt-tokens ${toString promptExcessTokenCount} \
        --max-new-tokens ${toString promptFixtureNewTokenCount} \
        >"$fixture_root/prompt-excess-limit.log" 2>&1; then
        echo "rwkv-prompt-harness accepted an excessive prompt limit" >&2
        exit 1
      fi
      grep -F 'max prompt tokens must be in' "$fixture_root/prompt-excess-limit.log"

      if $out/bin/rwkv-prompt-harness \
        --message Hello \
        --max-prompt-tokens 1 \
        --max-new-tokens ${toString promptFixtureNewTokenCount} \
        >"$fixture_root/prompt-actual-excess.log" 2>&1; then
        echo "rwkv-prompt-harness truncated a prompt over the caller limit" >&2
        exit 1
      fi
      grep -F 'exceeding caller limit 1' "$fixture_root/prompt-actual-excess.log"

      $out/bin/rwkv-ttwkv7-fixture >"$fixture_root/ttwkv7-boundary-first.json"
      $out/bin/rwkv-ttwkv7-fixture >"$fixture_root/ttwkv7-boundary-second.json"
      cmp "$fixture_root/ttwkv7-boundary-first.json" \
        "$fixture_root/ttwkv7-boundary-second.json"
      cmp "$fixture_root/ttwkv7-boundary-first.json" \
        "$out/share/rwkv-layer-harness/ttwkv7-boundary.json"
      grep -Fq '"target":"ttwkv7_logical_wkv_boundary"' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"arithmetic_precision":"little_endian_bf16_storage_cpu_fp32_recurrence"' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"input_order":["a","w","k","v","r","b"]' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"state_order":"head_row_column"' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"prefix_token_ids":[1,2]' \
        "$fixture_root/ttwkv7-boundary-first.json"
      test "$(grep -o '"name":' "$fixture_root/ttwkv7-boundary-first.json" | wc -l)" -eq 9
      test "$(grep -o '"byte_count":1536' "$fixture_root/ttwkv7-boundary-first.json" | wc -l)" -eq 7
      test "$(grep -o '"byte_count":98304' "$fixture_root/ttwkv7-boundary-first.json" | wc -l)" -eq 2
      test "$(grep -o '"bytes_hex":' "$fixture_root/ttwkv7-boundary-first.json" | wc -l)" -eq 9
      grep -Fq '"ordered_artifact_blake3":"${expectedTtwkv7BoundaryCombinedBlake3}"' \
        "$fixture_root/ttwkv7-boundary-first.json"
      for expected_blake3 in ${lib.escapeShellArgs expectedTtwkv7BoundaryArtifactBlake3}; do
        grep -Fq "\"blake3\":\"$expected_blake3\"" \
          "$fixture_root/ttwkv7-boundary-first.json"
      done
      for expected_blake3 in ${lib.escapeShellArgs expectedTtwkv7BoundarySourceBlake3}; do
        grep -Fq "\"blake3\":\"$expected_blake3\"" \
          "$fixture_root/ttwkv7-boundary-first.json"
      done
      grep -Fq '"maximum_input_quantization_deviation":${expectedTtwkv7BoundaryInputQuantizationDeviation}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"pre_state_quantization_deviation":${expectedTtwkv7BoundaryPreStateQuantizationDeviation}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"expected_output_vs_source_deviation":${expectedTtwkv7BoundaryOutputSourceDeviation}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"expected_post_state_vs_source_deviation":${expectedTtwkv7BoundaryPostStateSourceDeviation}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"matrix_oracle_output_deviation":${expectedTtwkv7BoundaryOracleOutputDeviation}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"matrix_oracle_state_deviation":${expectedTtwkv7BoundaryOracleStateDeviation}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq '"retained_pre_state_maximum_absolute_value":${expectedTtwkv7BoundaryRetainedStateMaximum}' \
        "$fixture_root/ttwkv7-boundary-first.json"
      grep -Fq 'No ttWKV7 kernel execution or numerical parity is established.' \
        "$fixture_root/ttwkv7-boundary-first.json"

      if $out/bin/rwkv-ttwkv7-fixture unexpected-argument \
        >"$fixture_root/ttwkv7-boundary-argument-rejection.log" 2>&1; then
        echo "rwkv-ttwkv7-fixture accepted a caller-controlled argument" >&2
        exit 1
      fi
      grep -F 'does not accept arguments' \
        "$fixture_root/ttwkv7-boundary-argument-rejection.log"

      if $out/bin/rwkv-layer-harness unexpected-argument \
        >"$fixture_root/argument-rejection.log" 2>&1; then
        echo "rwkv-layer-harness accepted a caller-controlled argument" >&2
        exit 1
      fi
      grep -F 'does not accept arguments' "$fixture_root/argument-rejection.log"

      if $out/bin/rwkv-token-harness unexpected-argument \
        >"$fixture_root/token-argument-rejection.log" 2>&1; then
        echo "rwkv-token-harness accepted a caller-controlled argument" >&2
        exit 1
      fi
      grep -F 'does not accept arguments' "$fixture_root/token-argument-rejection.log"

      if $out/bin/rwkv-decode-harness unexpected-argument \
        >"$fixture_root/decode-argument-rejection.log" 2>&1; then
        echo "rwkv-decode-harness accepted a caller-controlled argument" >&2
        exit 1
      fi
      grep -F 'does not accept arguments' "$fixture_root/decode-argument-rejection.log"

      if $out/bin/rwkv-text-harness unexpected-argument \
        >"$fixture_root/text-argument-rejection.log" 2>&1; then
        echo "rwkv-text-harness accepted a caller-controlled argument" >&2
        exit 1
      fi
      grep -F 'does not accept arguments' "$fixture_root/text-argument-rejection.log"

      if $out/bin/rwkv-framework-fixture unexpected-argument \
        >"$fixture_root/framework-argument-rejection.log" 2>&1; then
        echo "rwkv-framework-fixture accepted a caller-controlled argument" >&2
        exit 1
      fi
      grep -F 'does not accept arguments' "$fixture_root/framework-argument-rejection.log"

      if grep -E 'std::process::Command|Command::new|/dev/tenstorrent|TT_VISIBLE_DEVICES|Metalium|owner-control|retry' \
        ${./src/lib.rs} ${./src/main.rs} ${./src/bin/rwkv-token-harness.rs} ${./src/bin/rwkv-decode-harness.rs} ${./src/bin/rwkv-text-harness.rs} ${./src/bin/rwkv-prompt-harness.rs} ${./src/bin/rwkv-framework-fixture.rs} ${./src/bin/rwkv-ttwkv7-fixture.rs}; then
        echo "rwkv-layer-harness must not contain hardware or process orchestration" >&2
        exit 1
      fi

      cat "$fixture_root/first.json"
      cat "$fixture_root/token-first.json"
      cat "$fixture_root/decode-first.json"
      cat "$fixture_root/text-first.json"
      cat "$fixture_root/prompt-first.json"
      runHook postInstallCheck
    '';

    passthru = {
      inherit
        addedTokens
        flaRwkv7Source
        dispatchAbiCheck
        frameworkParityCheck
        modelCarryCheck
        modelDispatchCheck
        observedLayerReplayCheck
        persistentModelDispatchCheck
        stateCarryCheck
        generationConfig
        hfModelingSource
        model
        modelConfig
        officialRwkvSource
        specialTokensMap
        tokenizerConfig
        tokenizerImplementation
        tokenizerVocabulary
        ;
    };

    meta = {
      description = "Device-free real-weight RWKV-7 references and observed ttWKV7 layer replay";
      license = lib.licenses.mit;
      mainProgram = "rwkv-layer-harness";
      platforms = lib.platforms.linux;
    };
  };
in
package
