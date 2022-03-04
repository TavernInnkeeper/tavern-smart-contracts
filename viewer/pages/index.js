import Head from 'next/head'
import Image from 'next/image'
import styles from '../styles/Home.module.css'

import { ethers } from "ethers"
import { FetchWrapper, NftProvider, useNft } from "use-nft"
import { useEffect, useState } from 'react'

const RPC_URL = "http://127.0.0.1:8545"

// We are using the "ethers" fetcher here.
const ethersConfig = {
  provider: new ethers.providers.JsonRpcProvider(RPC_URL),
}

const fetcher = ["ethers", ethersConfig]

const fetchWrapper = new FetchWrapper(fetcher)

export default function Home() {
  return (
    <NftProvider fetcher={fetcher}>
      <Nft />
    </NftProvider>
  )
}

const myLoader = ({ src, width, quality }) => {
  return `${src}`
}

function Nft() {

  const [nft, setNft] = useState({"name": "", "description": "", "image": "https://example.com"});

  useEffect(() => {
    const interval = setInterval(() => {
      fetchWrapper.fetchNft(
        '0xb932C8342106776E73E39D695F3FFC3A9624eCE0',
        "1"
      ).then(r => {
        setNft(r);
        console.log("REsult", r);
      })
    }, 500);

    return () => {
      clearInterval(interval);
    }
  })
  // You can now display the NFT metadata.
  return (
    <section>
      <h1>{nft.name}</h1>
      <Image loader={myLoader} src={nft.image} alt="" width={500} height={500}/>
      <p>{nft.description}</p>
      <p>Owner: {nft.owner}</p>
      <p>Metadata URL: {nft.metadataUrl}</p>
    </section>
  )
}